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
    def self.builder(io : IO, *, buffer_size : Int32 = DEFAULT_BUFFER_SIZE) : {NonBlocking, WorkerGuard}
      channel = Channel(Bytes).new(buffer_size)
      done = Channel(Nil).new

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
        done.send(nil)
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
    @done : Channel(Nil)

    def initialize(@sender : Channel(Bytes), @done : Channel(Nil))
    end

    def close : Nil
      @sender.close
      @done.receive
    end

    def finalize
      close
    end
  end
end
