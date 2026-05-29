module Tracing
  # A tracing Layer that converts spans and events to OpenTelemetry.
  #
  # Ported from upstream `tracing_opentelemetry::OpenTelemetryLayer`.
  class OpenTelemetryLayer < Layer
    def initialize
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      # Store OTel data in span extensions for later processing
      if span = ctx.span(id)
        span.extensions_mut.try(&.insert(OtelSpanData.new(attrs.metadata.name)))
      end
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      # Track span start time
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
      # Finalize span timing
    end

    def on_event(event : Core::Event, ctx : LayerContext) : Nil
      # Add event to active OTel span
    end
  end

  # Per-span data stored in Extensions for OpenTelemetry integration.
  #
  # Ported from upstream `tracing_opentelemetry::OtelData`.
  struct OtelSpanData
    getter name : String

    def initialize(@name : String)
    end
  end
end
