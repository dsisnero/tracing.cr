module Tracing
  # Filter combinators — `FilterExt::and` / `::or` / `::not`.
  #
  # Ported from upstream `tracing_subscriber::filter::combinator`. The Crystal
  # port collapses Rust's `Filter` trait into `Layer`, so these combine layers
  # used as filters: the combinators combine `enabled?`, `on_register_callsite`
  # (callsite `Interest`), and `max_level_hint`, and forward span lifecycle
  # hooks to the wrapped filter(s).
  class Layer
    # Combines two filters so a span/event is enabled only if *both* enable it.
    def and(other : Layer) : And
      And.new(self, other)
    end

    # Combines two filters so a span/event is enabled if *either* enables it.
    def or(other : Layer) : Or
      Or.new(self, other)
    end

    # Inverts this filter: enables what it would disable and vice versa.
    def not : Not
      Not.new(self)
    end
  end

  # Enabled iff both wrapped filters are enabled.
  class And < Layer
    def initialize(@a : Layer, @b : Layer)
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      @a.enabled?(metadata, ctx) && @b.enabled?(metadata, ctx)
    end

    def on_register_callsite(metadata : Metadata, ctx : LayerContext) : Callsite::Interest
      a = @a.on_register_callsite(metadata, ctx)
      return a if a.never?
      b = @b.on_register_callsite(metadata, ctx)
      return b unless b.always?
      a
    end

    # The most restrictive (least verbose) of the two hints; nil if either is nil.
    def max_level_hint : LevelFilter?
      ha = @a.max_level_hint
      hb = @b.max_level_hint
      return unless ha && hb
      ha < hb ? ha : hb
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_new_span(attrs, id, ctx)
      @b.on_new_span(attrs, id, ctx)
    end

    def on_record(id : Core::Span::Id, values : Core::Span::Record, ctx : LayerContext) : Nil
      @a.on_record(id, values, ctx)
      @b.on_record(id, values, ctx)
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_enter(id, ctx)
      @b.on_enter(id, ctx)
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_exit(id, ctx)
      @b.on_exit(id, ctx)
    end

    def on_close(id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_close(id, ctx)
      @b.on_close(id, ctx)
    end
  end

  # Enabled iff either wrapped filter is enabled.
  class Or < Layer
    def initialize(@a : Layer, @b : Layer)
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      @a.enabled?(metadata, ctx) || @b.enabled?(metadata, ctx)
    end

    def on_register_callsite(metadata : Metadata, ctx : LayerContext) : Callsite::Interest
      a = @a.on_register_callsite(metadata, ctx)
      b = @b.on_register_callsite(metadata, ctx)
      return Callsite::Interest.always if a.always? || b.always?
      return Callsite::Interest.never if a.never? && b.never?
      Callsite::Interest.sometimes
    end

    # The least restrictive (most verbose) of the two hints; nil if either is nil.
    def max_level_hint : LevelFilter?
      ha = @a.max_level_hint
      hb = @b.max_level_hint
      return unless ha && hb
      ha < hb ? hb : ha
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_new_span(attrs, id, ctx)
      @b.on_new_span(attrs, id, ctx)
    end

    def on_record(id : Core::Span::Id, values : Core::Span::Record, ctx : LayerContext) : Nil
      @a.on_record(id, values, ctx)
      @b.on_record(id, values, ctx)
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_enter(id, ctx)
      @b.on_enter(id, ctx)
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_exit(id, ctx)
      @b.on_exit(id, ctx)
    end

    def on_close(id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_close(id, ctx)
      @b.on_close(id, ctx)
    end
  end

  # Inverts the wrapped filter's `enabled?` and callsite `Interest`.
  class Not < Layer
    def initialize(@a : Layer)
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      !@a.enabled?(metadata, ctx)
    end

    def on_register_callsite(metadata : Metadata, ctx : LayerContext) : Callsite::Interest
      interest = @a.on_register_callsite(metadata, ctx)
      return Callsite::Interest.never if interest.always?
      return Callsite::Interest.always if interest.never?
      Callsite::Interest.sometimes
    end

    # Upstream returns `None` (the inverted level range is not expressible).
    def max_level_hint : LevelFilter?
      nil
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_new_span(attrs, id, ctx)
    end

    def on_record(id : Core::Span::Id, values : Core::Span::Record, ctx : LayerContext) : Nil
      @a.on_record(id, values, ctx)
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_enter(id, ctx)
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_exit(id, ctx)
    end

    def on_close(id : Core::Span::Id, ctx : LayerContext) : Nil
      @a.on_close(id, ctx)
    end
  end
end
