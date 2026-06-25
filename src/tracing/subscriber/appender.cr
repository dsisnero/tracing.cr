module Tracing
  # A non-blocking writer that spawns a worker fiber for I/O.
  #
  # Messages are sent via Channel to the worker fiber which writes
  # them to the underlying IO. This prevents blocking the calling
  # fiber on slow I/O.
  #
  # Ported from upstream `tracing_appender::non_blocking`.
  class NonBlocking
    DEFAULT_BUFFER_SIZE = 128_000

    @sender : Channel(Bytes)

    # Create a new NonBlocking writer wrapping the given IO.
    def self.new(io : IO, buffer_size : Int32 = DEFAULT_BUFFER_SIZE) : {NonBlocking, WorkerGuard}
      builder(io, buffer_size: buffer_size)
    end

    # Builder-style constructor.
    #
    # Options:
    #   buffer_size: channel buffer capacity (default: 128_000)
    #   lossy: drop messages when buffer is full (default: false, backpressure)
    #
    # NOTE: lossy mode is a placeholder — Crystal's Channel supports
    # only blocking send. In non-lossy mode (default), send blocks until
    # the worker drains the buffer. Lossy will be implemented when
    # Crystal adds non-blocking Channel send.
    def self.builder(io : IO, *, buffer_size : Int32 = DEFAULT_BUFFER_SIZE, lossy : Bool = false) : {NonBlocking, WorkerGuard}
      channel = Channel(Bytes).new(buffer_size)
      done = Channel(Bool).new

      spawn(name: "tracing-appender-worker") do
        loop do
          msg = begin
            channel.receive
          rescue Channel::ClosedError
            break
          end
          begin
            io.write(msg)
            io.flush
          rescue ex
            break
          end
        end
        done.send(true)
      end

      Fiber.yield

      nb = new(channel)
      guard = WorkerGuard.new(channel, done)
      {nb, guard}
    end

    private def initialize(@sender : Channel(Bytes))
    end

    # Returns a MakeWriter-compatible IO that sends to the worker.
    def make_writer : NonBlockingWriter
      NonBlockingWriter.new(@sender)
    end
  end

  # An IO-like writer that sends bytes to the NonBlocking worker fiber.
  class NonBlockingWriter < IO
    @sender : Channel(Bytes)

    def initialize(@sender : Channel(Bytes))
    end

    def write(slice : Bytes) : Nil
      @sender.send(slice.dup)
    end

    def read(slice : Bytes) : NoReturn
      raise IO::Error.new("NonBlockingWriter is write-only")
    end
  end

  # Ensures the worker fiber is shut down and buffered data is flushed.
  #
  # Must be held in a variable (not `_`) to prevent immediate drop.
  class WorkerGuard
    @sender : Channel(Bytes)
    @done : Channel(Bool)
    @closed = Atomic(Bool).new(false)

    def initialize(@sender : Channel(Bytes), @done : Channel(Bool))
    end

    # Flush buffered data and shut down the worker fiber.
    #
    # Idempotent: only the first call closes the sender and waits for
    # the worker to drain. Subsequent calls (including the one issued
    # by `finalize` during GC) are no-ops, so they cannot deadlock on
    # `@done.receive` after the worker fiber has already terminated.
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

  # Rotation schedule for rolling log files.
  enum Rotation
    MINUTELY
    HOURLY
    DAILY
    NEVER
  end

  # A file appender that rotates log files on a fixed schedule.
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

    # Returns a new `Builder` for configuring a `RollingFileAppender`.
    def self.builder : Builder
      Builder.new
    end

    # Configures and constructs a `RollingFileAppender`.
    #
    # Ported from upstream `tracing_appender::rolling::Builder`. Defaults:
    # rotation `NEVER`, no prefix/suffix, no file limit. An empty prefix or
    # suffix is treated as unset.
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

    # Builds the log filename for `date`, mirroring upstream `join_date`:
    # prefix/suffix and (for rotating schedules) the date are joined with `.`.
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

    # Deletes the oldest matching log files so that at most `max_files - 1`
    # remain before the next file is created. Mirrors upstream `prune_old_logs`.
    #
    # Divergence: upstream orders by file creation time (falling back to the
    # date parsed from the filename); Crystal's `File::Info` exposes
    # modification time, so files are ordered by modification time instead.
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
