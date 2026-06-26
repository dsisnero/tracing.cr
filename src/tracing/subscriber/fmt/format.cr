module Tracing
  module FmtFormat
    # A writer to which formatted representations of spans and events are written.
    #
    # Ported from upstream `tracing_subscriber::fmt::format::Writer`.
    struct Writer
      getter io : IO
      getter? has_ansi_escapes : Bool

      def initialize(@io : IO, @has_ansi_escapes : Bool = false)
      end
    end

    # A type that can format a set of fields to a Writer.
    #
    # Ported from upstream `tracing_subscriber::fmt::format::FormatFields`.
    abstract class FormatFields
      abstract def format_fields(writer : Writer, values : Field::ValueSet) : Nil
    end

    # A type that can format a tracing Event to a Writer.
    #
    # Ported from upstream `tracing_subscriber::fmt::format::FormatEvent`.
    abstract class FormatEvent
      abstract def format_event(ctx : LayerContext, writer : Writer, event : Core::Event) : Nil
    end

    # Default field formatter — writes `key=value` pairs separated by spaces.
    #
    # Ported from upstream `tracing_subscriber::fmt::format::DefaultFields`.
    class DefaultFields < FormatFields
      include Core::Field::Visit

      @writer : IO?
      @first : Bool = true

      def format_fields(writer : Writer, values : Field::ValueSet) : Nil
        @writer = writer.io
        @first = true
        values.visit(self)
      end

      def record_debug(field : Field::Field, value) : Nil
        write_field(field.name, value.to_s)
      end

      def record_i64(field : Field::Field, value : Int64) : Nil
        write_field(field.name, value.to_s)
      end

      def record_u64(field : Field::Field, value : UInt64) : Nil
        write_field(field.name, value.to_s)
      end

      def record_f64(field : Field::Field, value : Float64) : Nil
        write_field(field.name, value.to_s)
      end

      def record_bool(field : Field::Field, value : Bool) : Nil
        write_field(field.name, value.to_s)
      end

      def record_str(field : Field::Field, value : String) : Nil
        write_field(field.name, value)
      end

      def record_error(field : Field::Field, value : Exception) : Nil
        write_field(field.name, value.message || "")
      end

      private def write_field(key : String, val : String) : Nil
        w = @writer.not_nil!
        w << " " unless @first
        w << key << "=" << val
        @first = false
      end
    end
  end
end
