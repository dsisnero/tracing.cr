module Tracing
  # A reference to span data with mutable extensions access.
  #
  # Ported from upstream `tracing_subscriber::registry::SpanRef`.
  struct SpanRef
    getter name : String
    getter metadata : Metadata
    getter parent_id : Core::Span::Id?
    @registry : Registry
    @span_id : Core::Span::Id

    def initialize(@name, @metadata, @parent_id, @registry, @span_id)
    end

    # Returns this span's parent `SpanRef`, or `nil` if it is a root span.
    def parent : SpanRef?
      pid = @parent_id
      return unless pid
      @registry.span(pid)
    end

    # Returns an iterator over this span and its ancestors, ordered leaf to
    # root (this span first, then its parent, and so on). Mirrors upstream
    # `SpanRef::scope`; call `#from_root` on the result to reverse the order.
    def scope : Scope
      Scope.new(@registry, @span_id)
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

  # An iterator over a span and its ancestors, ordered leaf to root.
  #
  # Ported from upstream `tracing_subscriber::registry::Scope`.
  class Scope
    include Iterator(SpanRef)

    @registry : Registry
    @next_id : Core::Span::Id?

    def initialize(@registry : Registry, @next_id : Core::Span::Id?)
    end

    def next
      id = @next_id
      return stop if id.nil?
      span = @registry.span(id)
      return stop if span.nil?
      @next_id = span.parent_id
      span
    end

    # Flips the order to root-to-leaf. Mirrors upstream `Scope::from_root`.
    def from_root : Iterator(SpanRef)
      to_a.reverse!.each
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

  class Layered(S)
    include LookupSpan

    def span_data(id : Core::Span::Id) : Registry::SpanData?
      @inner.as?(LookupSpan).try(&.span_data(id))
    end

    def span(id : Core::Span::Id) : SpanRef?
      @inner.as?(LookupSpan).try(&.span(id))
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
