module Tracing
  DEFAULT_BUFFERED_LINES_LIMIT = 128_000

  class ErrorCounter
    @counter : Atomic(UInt64)

    def initialize
      @counter = Atomic(UInt64).new(0)
    end

    def dropped_lines : UInt64
      @counter.get
    end

    def incr_saturating
      loop do
        curr = @counter.get
        return if curr == UInt64::MAX
        _, succeeded = @counter.compare_and_set(curr, curr + 1)
        return if succeeded
      end
    end
  end

  class NonBlockingBuilder
    @buffered_lines_limit : Int32
    @is_lossy : Bool
    @thread_name : String

    def initialize
      @buffered_lines_limit = DEFAULT_BUFFERED_LINES_LIMIT
      @is_lossy = true
      @thread_name = "tracing-appender"
    end

    def buffered_lines_limit(n : Int32) : self
      @buffered_lines_limit = n
      self
    end

    def lossy(yes : Bool) : self
      @is_lossy = yes
      self
    end

    def thread_name(name : String) : self
      @thread_name = name
      self
    end

    def finish(io : IO) : {NonBlocking, WorkerGuard}
      NonBlocking.create(io, @buffered_lines_limit, @is_lossy, @thread_name)
    end
  end

  class NonBlocking
    @sender : Channel(Bytes)
    @is_lossy : Bool
    @error_counter : ErrorCounter

    def self.new(io : IO, buffer_size : Int32 = DEFAULT_BUFFERED_LINES_LIMIT) : {NonBlocking, WorkerGuard}
      NonBlockingBuilder.new.buffered_lines_limit(buffer_size).finish(io)
    end

    def self.builder(io : IO, *, buffer_size : Int32 = DEFAULT_BUFFERED_LINES_LIMIT, lossy : Bool = true) : {NonBlocking, WorkerGuard}
      NonBlockingBuilder.new.buffered_lines_limit(buffer_size).lossy(lossy).finish(io)
    end

    def self.create(io : IO, buffered_lines_limit : Int32, is_lossy : Bool, thread_name : String) : {NonBlocking, WorkerGuard}
      channel = Channel(Bytes).new(buffered_lines_limit)
      done = Channel(Bool).new

      spawn(name: thread_name) do
        loop do
          msg = begin
            channel.receive
          rescue Channel::ClosedError
            break
          end
          io.write(msg)
          io.flush
        end
        done.send(true)
      end

      Fiber.yield

      error_counter = ErrorCounter.new
      nb = new(channel, is_lossy, error_counter)
      guard = WorkerGuard.new(channel, done)
      {nb, guard}
    end

    private def initialize(@sender : Channel(Bytes), @is_lossy : Bool, @error_counter : ErrorCounter)
    end

    def make_writer : NonBlockingWriter
      NonBlockingWriter.new(@sender, @is_lossy, @error_counter)
    end

    def error_counter : ErrorCounter
      @error_counter
    end
  end

  class NonBlockingWriter < IO
    def initialize(@sender : Channel(Bytes), @is_lossy : Bool, @error_counter : ErrorCounter)
    end

    def write(slice : Bytes) : Nil
      if @is_lossy
        select
        when @sender.send(slice.dup)
        else
          @error_counter.incr_saturating
        end
      else
        @sender.send(slice.dup)
      end
    end

    def read(slice : Bytes) : NoReturn
      raise IO::Error.new("NonBlockingWriter is write-only")
    end
  end

  class WorkerGuard
    @sender : Channel(Bytes)
    @done : Channel(Bool)
    @closed = Atomic(Bool).new(false)

    def initialize(@sender : Channel(Bytes), @done : Channel(Bool))
    end

    def close : Nil
      _, succeeded = @closed.compare_and_set(false, true)
      return unless succeeded
      @sender.close
      @done.receive
    end

    def finalize
      close
    end
  end

  enum Rotation
    MINUTELY
    HOURLY
    DAILY
    NEVER
  end

  class RollingFileAppender
    @rotation : Rotation
    @directory : String
    @prefix : String?
    @suffix : String?
    @max_files : Int32?
    @file : File?
    @current_date : String?

    def initialize(@rotation : Rotation, @directory : String, @prefix : String?, @suffix : String? = nil, @max_files : Int32? = nil)
      Dir.mkdir_p(@directory)
      rotate
    end

    def self.builder : Builder
      Builder.new
    end

    class Builder
      @rotation : Rotation
      @prefix : String?
      @suffix : String?
      @max_files : Int32?

      def initialize
        @rotation = Rotation::NEVER
        @prefix = nil
        @suffix = nil
        @max_files = nil
      end

      def rotation(rotation : Rotation) : self
        @rotation = rotation
        self
      end

      def filename_prefix(prefix : String) : self
        @prefix = prefix.empty? ? nil : prefix
        self
      end

      def filename_suffix(suffix : String) : self
        @suffix = suffix.empty? ? nil : suffix
        self
      end

      def max_log_files(n : Int32) : self
        @max_files = n
        self
      end

      def build(directory : String) : RollingFileAppender
        RollingFileAppender.new(@rotation, directory, @prefix, @suffix, @max_files)
      end
    end

    def write(slice : Bytes) : Nil
      rotate_if_needed
      @file.try(&.write(slice))
      @file.try(&.flush)
    end

    def close : Nil
      @file.try(&.close)
      @file = nil
    end

    private def rotate_if_needed : Nil
      current = date_suffix
      if @current_date != current
        close
        @current_date = current
        prune_old_logs
        @file = File.open(File.join(@directory, build_filename(current)), mode: "a")
      end
    end

    private def build_filename(date : String) : String
      prefix = @prefix
      suffix = @suffix
      if @rotation.never?
        if prefix && suffix
          "#{prefix}.#{suffix}"
        elsif prefix
          prefix
        elsif suffix
          suffix
        else
          date
        end
      elsif prefix && suffix
        "#{prefix}.#{date}.#{suffix}"
      elsif prefix
        "#{prefix}.#{date}"
      elsif suffix
        "#{date}.#{suffix}"
      else
        date
      end
    end

    private def prune_old_logs : Nil
      max = @max_files
      return unless max
      files = matching_log_files
      return if files.size < max
      files.sort_by! { |entry| entry[:mtime] }
      files.first(files.size - (max - 1)).each do |entry|
        File.delete?(entry[:path])
      end
    end

    private def matching_log_files : Array({path: String, mtime: Time})
      prefix = @prefix
      suffix = @suffix
      result = [] of {path: String, mtime: Time}
      Dir.each_child(@directory) do |name|
        next if prefix && !name.starts_with?(prefix)
        next if suffix && !name.ends_with?(suffix)
        path = File.join(@directory, name)
        next unless File.file?(path)
        result << {path: path, mtime: File.info(path).modification_time}
      end
      result
    end

    private def rotate : Nil
      @current_date = nil
      rotate_if_needed
    end

    private def date_suffix : String
      t = Time.local
      case @rotation
      in .minutely? then t.to_s("%Y-%m-%d-%H-%M")
      in .hourly?   then t.to_s("%Y-%m-%d-%H")
      in .daily?    then t.to_s("%Y-%m-%d")
      in .never?    then ""
      end
    end

    def finalize
      close
    end
  end
end
