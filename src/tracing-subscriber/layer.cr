module Tracing
  # A Layer observes trace data from a Subscriber.
  #
  # Ported from upstream `tracing_subscriber::layer::Layer`.
  abstract class Layer
    # Called when an event is recorded.
    def on_event(event : Core::Event, ctx : LayerContext) : Nil
    end

    # Called when a new span is created.
    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
    end

    # Called when a span is entered.
    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
    end

    # Called when a span is exited.
    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
    end

    # Called when fields are recorded on a span.
    def on_record(id : Core::Span::Id, values : Core::Span::Record, ctx : LayerContext) : Nil
    end

    # Called when a follows-from relationship is recorded.
    def on_record_follows_from(span : Core::Span::Id, follows : Core::Span::Id, ctx : LayerContext) : Nil
    end

    # Called when a callsite is registered.
    def on_register_callsite(metadata : Metadata, ctx : LayerContext) : Callsite::Interest
      Callsite::Interest.always
    end

    # Returns true if this layer would enable the given metadata.
    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      true
    end

    # Returns the max level hint for this layer.
    def max_level_hint : LevelFilter?
      nil
    end

    # Compose this layer with another, where `other` acts as a filter.
    def and_then(other : Layer) : Filtered
      Filtered.new(self, other)
    end
  end

  # A layer combinator that applies a filter layer to an inner layer.
  class Filtered < Layer
    @inner : Layer
    @filter : Layer

    def initialize(@inner : Layer, @filter : Layer)
    end

    def on_event(event : Core::Event, ctx : LayerContext) : Nil
      @inner.on_event(event, ctx)
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      @inner.on_new_span(attrs, id, ctx)
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      @inner.on_enter(id, ctx)
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
      @inner.on_exit(id, ctx)
    end

    def on_record(id : Core::Span::Id, values : Core::Span::Record, ctx : LayerContext) : Nil
      @inner.on_record(id, values, ctx)
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      @filter.enabled?(metadata, ctx)
    end

    def on_register_callsite(metadata : Metadata, ctx : LayerContext) : Callsite::Interest
      @filter.on_register_callsite(metadata, ctx)
    end

    def max_level_hint : LevelFilter?
      @filter.max_level_hint
    end
  end

  # Context passed to Layer methods, providing access to the subscriber.
  class LayerContext
    @subscriber : Core::Subscriber

    def initialize(@subscriber : Core::Subscriber)
    end

    # Look up span data from the subscriber (if it supports LookupSpan).
    def span(id : Core::Span::Id) : Registry::SpanData?
      if @subscriber.is_a?(Registry)
        @subscriber.as(Registry).span_data(id)
      end
    end

    def subscriber : Core::Subscriber
      @subscriber
    end
  end

  # A Subscriber composed of a base subscriber and a Layer.
  #
  # All Subscriber methods delegate to the inner subscriber first,
  # then call the corresponding Layer hook.
  class Layered(S)
    include Core::Subscriber

    getter inner : S
    getter layer : Layer

    def initialize(@inner : S, @layer : Layer)
    end

    def new_span(attrs : Core::Span::Attributes) : Core::Span::Id
      ctx = LayerContext.new(@inner)
      id = @inner.new_span(attrs)
      @layer.on_new_span(attrs, id, ctx)
      id
    end

    def enter(id : Core::Span::Id) : Nil
      @inner.enter(id)
      ctx = LayerContext.new(@inner)
      if @layer.enabled?(Metadata.new("", "", Level::TRACE), ctx)
        @layer.on_enter(id, ctx)
      end
    end

    def exit(id : Core::Span::Id) : Nil
      @inner.exit(id)
      ctx = LayerContext.new(@inner)
      if @layer.enabled?(Metadata.new("", "", Level::TRACE), ctx)
        @layer.on_exit(id, ctx)
      end
    end

    def event(event : Core::Event) : Nil
      @inner.event(event)
      ctx = LayerContext.new(@inner)
      if @layer.enabled?(event.metadata, ctx)
        @layer.on_event(event, ctx)
      end
    end

    def record(id : Core::Span::Id, values : Core::Span::Record) : Nil
      @inner.record(id, values)
      ctx = LayerContext.new(@inner)
      if @layer.enabled?(Metadata.new("", "", Level::TRACE), ctx)
        @layer.on_record(id, values, ctx)
      end
    end

    def record_follows_from(span : Core::Span::Id, follows : Core::Span::Id) : Nil
      @inner.record_follows_from(span, follows)
      ctx = LayerContext.new(@inner)
      if @layer.enabled?(Metadata.new("", "", Level::TRACE), ctx)
        @layer.on_record_follows_from(span, follows, ctx)
      end
    end

    def enabled(metadata : Metadata) : Bool
      ctx = LayerContext.new(@inner)
      @layer.enabled?(metadata, ctx)
    end

    def register_callsite(metadata : Metadata) : Callsite::Interest
      @layer.on_register_callsite(metadata, LayerContext.new(@inner))
    end

    def max_level_hint : LevelFilter?
      @layer.max_level_hint
    end
  end

  # Add a layer to a subscriber, returning a Layered subscriber.
  class Registry
    def with(layer : Layer) : Layered(Registry)
      Layered.new(self, layer)
    end

    def with(layer : Nil) : Layered(Registry)
      Layered.new(self, NoOpLayer.new)
    end
  end

  class Layered(S)
    def with(layer : Layer) : Layered(Layered(S))
      Layered.new(self, layer)
    end

    def with(layer : Nil) : Layered(Layered(S))
      Layered.new(self, NoOpLayer.new)
    end

    def init : Nil
      Tracing::Subscriber.set_global_default(self)
    end
  end

  # A no-op layer that passes everything through.
  class NoOpLayer < Layer
    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      true
    end

    def max_level_hint : LevelFilter?
      nil
    end
  end
end
