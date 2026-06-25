module Tracing
  module FmtWriter
    # A type that can create `IO` instances.
    #
    # Ported from upstream `tracing_subscriber::fmt::writer::MakeWriter`.
    abstract class MakeWriter
      abstract def make_writer(meta : Metadata?) : IO
    end

    # Wraps a `-> IO` block as a `MakeWriter`.
    class MakeWriter::Proc < MakeWriter
      def initialize(&@block : -> IO)
      end

      def make_writer(meta : Metadata?) : IO
        @block.call
      end
    end

    # An `IO` implementation that discards all writes.
    #
    # Ported from upstream `std::io::Sink` (used by `OptionalWriter::none`).
    class NoopWriter < IO
      def read(slice : Bytes) : Int32
        0
      end

      def write(slice : Bytes) : Nil
        # discard
      end
    end

    # Combines a MakeWriter with a maximum verbosity Level.
    #
    # Ported from upstream `tracing_subscriber::fmt::writer::WithMaxLevel`.
    class WithMaxLevel < MakeWriter
      def initialize(@inner : MakeWriter, @level : Level)
      end

      def make_writer(meta : Metadata?) : IO
        if meta && meta.level <= @level
          @inner.make_writer(meta)
        else
          NoopWriter.new
        end
      end
    end

    # Combines a MakeWriter with a minimum verbosity Level.
    #
    # Ported from upstream `tracing_subscriber::fmt::writer::WithMinLevel`.
    class WithMinLevel < MakeWriter
      def initialize(@inner : MakeWriter, @level : Level)
      end

      def make_writer(meta : Metadata?) : IO
        if meta && meta.level >= @level
          @inner.make_writer(meta)
        else
          NoopWriter.new
        end
      end
    end

    # Combines a MakeWriter with a metadata predicate filter.
    #
    # Ported from upstream `tracing_subscriber::fmt::writer::WithFilter`.
    class WithFilter < MakeWriter
      def initialize(@inner : MakeWriter, @filter : Metadata -> Bool)
      end

      def make_writer(meta : Metadata?) : IO
        if meta.nil?
          @inner.make_writer(meta)
        elsif @filter.call(meta)
          @inner.make_writer(meta)
        else
          NoopWriter.new
        end
      end
    end

    # An IO implementation that writes to two underlying writers.
    #
    # Ported from upstream `tracing_subscriber::fmt::writer::Tee` (Write impl).
    class TeeWriter < IO
      def initialize(@a : IO, @b : IO)
      end

      def read(slice : Bytes) : Int32
        raise IO::Error.new("TeeWriter does not support reading")
      end

      def write(slice : Bytes) : Nil
        @a.write(slice)
        @b.write(slice)
      end

      def close : Nil
        @a.close
        @b.close
      end
    end

    # Combines two MakeWriters to produce a writer that writes to both.
    #
    # Ported from upstream `tracing_subscriber::fmt::writer::Tee`.
    class Tee < MakeWriter
      def initialize(@a : MakeWriter, @b : MakeWriter)
      end

      def make_writer(meta : Metadata?) : IO
        TeeWriter.new(@a.make_writer(meta), @b.make_writer(meta))
      end
    end

    # Falls through to a second MakeWriter when the first returns NoopWriter.
    #
    # Ported from upstream `tracing_subscriber::fmt::writer::OrElse`.
    class OrElse < MakeWriter
      def initialize(@inner : MakeWriter, @or_else : MakeWriter)
      end

      def make_writer(meta : Metadata?) : IO
        writer = @inner.make_writer(meta)
        if writer.is_a?(NoopWriter)
          @or_else.make_writer(meta)
        else
          writer
        end
      end
    end

    # A writer intended to support output capturing in unit tests.
    #
    # Ported from upstream `tracing_subscriber::fmt::writer::TestWriter`.
    # In Crystal, `crystal spec` captures STDOUT output via `print`, so
    # this delegates writes to STDOUT.
    class TestWriter < IO
      def read(slice : Bytes) : Int32
        raise IO::Error.new("TestWriter does not support reading")
      end

      def write(slice : Bytes) : Nil
        STDOUT.write(slice)
      end
    end
  end
end
