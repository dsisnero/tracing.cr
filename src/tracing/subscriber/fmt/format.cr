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
  end
end
