module Tracing
  # A reference to span data retrieved from a LookupSpan subscriber.
  #
  # Ported from upstream `tracing_subscriber::registry::SpanRef`.
  struct SpanRef
    getter name : String
    getter metadata : Metadata
    getter parent : Core::Span::Id?

    def initialize(@name, @metadata, @parent = nil)
    end
  end

  # Trait for subscribers that can look up span data by ID.
  #
  # Ported from upstream `tracing_subscriber::registry::LookupSpan`.
  module LookupSpan
    abstract def span_data(id : Core::Span::Id) : Registry::SpanData?
    abstract def span(id : Core::Span::Id) : SpanRef?
  end

  # Looks up span data stored in a Registry.
  class Registry
    include LookupSpan

    # Returns a SpanRef for the span with the given ID.
    def span(id : Core::Span::Id) : SpanRef?
      data = span_data(id)
      return unless data

      SpanRef.new(data.name, data.metadata, data.parent)
    end
  end

  # Adds event_span method to look up the parent span of an event.
  class LayerContext
    def event_span(event : Core::Event) : SpanRef?
      return if event.root?
      subscriber = @subscriber.as?(LookupSpan)
      return unless subscriber

      if event.contextual?
        if registry = @subscriber.as?(Registry)
          if current_id = registry.current_span
            return subscriber.span(current_id)
          end
        end
        return
      end

      if event.has_explicit_parent?
        if parent_id = event.parent.id
          return subscriber.span(parent_id)
        end
      end

      nil
    end
  end
end
