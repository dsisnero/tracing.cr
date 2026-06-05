module Tracing
  # A reference to span data with mutable extensions access.
  #
  # Ported from upstream `tracing_subscriber::registry::SpanRef`.
  struct SpanRef
    getter name : String
    getter metadata : Metadata
    getter parent : Core::Span::Id?
    @registry : Registry
    @span_id : Core::Span::Id

    def initialize(@name, @metadata, @parent, @registry, @span_id)
    end

    # Get immutable access to span extensions.
    def extensions : Extensions?
      @registry.span_data(@span_id).try(&.extensions)
    end

    # Get mutable access to span extensions.
    def extensions_mut : ExtensionsMut?
      data = @registry.span_data(@span_id)
      return unless data
      ExtensionsMut.new(data.extensions)
    end
  end

  # Trait for subscribers that can look up span data by ID.
  module LookupSpan
    abstract def span_data(id : Core::Span::Id) : Registry::SpanData?
    abstract def span(id : Core::Span::Id) : SpanRef?
  end

  # Looks up span data stored in a Registry.
  class Registry
    include LookupSpan

    def span(id : Core::Span::Id) : SpanRef?
      data = span_data(id)
      return unless data

      SpanRef.new(data.name, data.metadata, data.parent, self, id)
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
          if current_id = registry.current_span_id
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

    # Look up span data from the context's subscriber.
    def span(id : Core::Span::Id) : SpanRef?
      subscriber = @subscriber.as?(LookupSpan)
      subscriber.try(&.span(id))
    end
  end
end
