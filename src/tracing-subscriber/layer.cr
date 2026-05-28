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
      @layer.on_enter(id, LayerContext.new(@inner))
    end

    def exit(id : Core::Span::Id) : Nil
      @inner.exit(id)
      @layer.on_exit(id, LayerContext.new(@inner))
    end

    def event(event : Core::Event) : Nil
      ctx = LayerContext.new(@inner)
      if @layer.enabled?(event.metadata, ctx)
        @inner.event(event)
        @layer.on_event(event, ctx)
      end
    end

    def record(id : Core::Span::Id, values : Core::Span::Record) : Nil
      @inner.record(id, values)
      @layer.on_record(id, values, LayerContext.new(@inner))
    end

    def record_follows_from(span : Core::Span::Id, follows : Core::Span::Id) : Nil
      @inner.record_follows_from(span, follows)
      @layer.on_record_follows_from(span, follows, LayerContext.new(@inner))
    end

    def enabled(metadata : Metadata) : Bool
      ctx = LayerContext.new(@inner)
      @inner.enabled(metadata) && @layer.enabled?(metadata, ctx)
    end

    def register_callsite(metadata : Metadata) : Callsite::Interest
      inner_interest = @inner.register_callsite(metadata)
      layer_interest = @layer.on_register_callsite(metadata, LayerContext.new(@inner))
      inner_interest.and(layer_interest)
    end

    def max_level_hint : LevelFilter?
      hint = @inner.max_level_hint
      layer_hint = @layer.max_level_hint
      if hint && layer_hint
        hint > layer_hint ? hint : layer_hint
      else
        hint || layer_hint
      end
    end
  end

  # Add a layer to a subscriber, returning a Layered subscriber.
  class Registry
    def with(layer : Layer) : Layered(Registry)
      Layered.new(self, layer)
    end
  end
end
