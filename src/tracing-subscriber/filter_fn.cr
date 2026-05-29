module Tracing
  # A filter that uses a closure to determine if events/spans are enabled.
  #
  # Ported from upstream `tracing_subscriber::filter::FilterFn`.
  class FilterFn < Layer
    @filter : Metadata -> Bool

    def initialize(&@filter : Metadata -> Bool)
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      @filter.call(metadata)
    end
  end

  # Extension: add with_fn_filter to Layer to wrap with a FilterFn.
  abstract class Layer
    def with_fn_filter(filter : FilterFn) : Filtered
      Filtered.new(self, filter)
    end
  end

  # A layer combinator that applies a FilterFn to an inner layer.
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
end
