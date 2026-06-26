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

    # Provides the current span context to an event formatter.
    #
    # Ported from upstream `tracing_subscriber::fmt::fmt_layer::FmtContext`.
    struct FmtContext
      getter ctx : LayerContext
      getter field_format : FormatFields
      getter event : Core::Event

      def initialize(@ctx : LayerContext, @field_format : FormatFields, @event : Core::Event)
      end

      def event_span(event : Core::Event)
        @ctx.event_span(event)
      end
    end

    # A type that can format a tracing Event to a Writer.
    #
    # Ported from upstream `tracing_subscriber::fmt::format::FormatEvent`.
    abstract class FormatEvent
      abstract def format_event(ctx : FmtContext, writer : Writer, event : Core::Event) : Nil
    end

    # Default event formatter — writes human-readable single-line logs.
    #
    # Ported from upstream `tracing_subscriber::fmt::format::Full`.
    class DefaultFormatEvent < FormatEvent
      @show_target : Bool
      @show_level : Bool
      @compact_mode : Bool
      @pretty_mode : Bool
      @use_ansi : Bool
      @timer : FmtTime::FormatTime?
      @show_thread_ids : Bool
      @show_thread_names : Bool

      def initialize(
        @show_target : Bool = false,
        @show_level : Bool = true,
        @compact_mode : Bool = false,
        @pretty_mode : Bool = false,
        @use_ansi : Bool = false,
        @timer : FmtTime::FormatTime? = nil,
        @show_thread_ids : Bool = false,
        @show_thread_names : Bool = false,
      )
      end

      def format_event(ctx : FmtContext, writer : Writer, event : Core::Event) : Nil
        io = writer.io
        span_name = ctx.event_span(event).try(&.name) || ""

        unless @compact_mode
          write_timestamp(io)
        end
        if @show_level
          write_level(io, event.metadata.level)
          io << " "
        end
        write_thread_info(io)
        if @show_target
          io << event.metadata.target << " "
        end
        unless span_name.empty?
          io << span_name << ":"
        end
        io << event.metadata.name

        if @pretty_mode
          io << ":\n"
        end

        vs = event.values
        if !vs.empty?
          if @pretty_mode
            # Pretty mode line-by-line
            buf_io = IO::Memory.new
            buf_writer = Writer.new(buf_io)
            ctx.field_format.format_fields(buf_writer, vs)
            buf_io.to_s.split(" ").each do |pair|
              io << "  " << pair << "\n"
            end
          else
            io << "{"
            ctx.field_format.format_fields(writer, vs)
            io << "}"
          end
        end

        io << "\n" unless @pretty_mode
      end

      private def write_timestamp(io : IO) : Nil
        if t = @timer
          t.format_time(io)
          io << " "
        end
      end

      private def write_level(io : IO, level : Level) : Nil
        if @use_ansi
          io << level_color(level)
          io << level.as_str.rjust(@compact_mode ? 0 : 5)
          io << "\e[0m"
        else
          io << level.as_str.rjust(@compact_mode ? 0 : 5)
        end
      end

      private def level_color(level : Level) : String
        case level
        in .error? then "\e[31m"
        in .warn?  then "\e[33m"
        in .info?  then "\e[32m"
        in .debug? then "\e[34m"
        in .trace? then "\e[36m"
        end
      end

      private def write_thread_info(io : IO) : Nil
        if @show_thread_names
          if name = Fiber.current.name
            io << name << " "
          elsif !@show_thread_ids
            io << Fiber.current.object_id << " "
          end
        end
        if @show_thread_ids
          io << Fiber.current.object_id << " "
        end
      end
    end

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
