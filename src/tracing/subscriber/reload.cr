module Tracing
  # Wraps a `Layer`, allowing it to be replaced at runtime via a `Handle`.
  #
  # Ported from upstream `tracing_subscriber::reload`. All `Layer` hooks
  # delegate to the *current* inner layer (guarded by a mutex), so swapping the
  # inner layer through the handle immediately changes behavior.
  #
  # Divergence from upstream: upstream additionally rebuilds the global callsite
  # interest cache on reload (`callsite::rebuild_interest_cache`). The Crystal
  # port leaves global interest management to the dispatcher — `Dispatch
  # .with_default` is fiber-local and does not register a global dispatcher, so
  # `Reload` only swaps the inner layer. Upstream's weak-reference / lock-
  # poisoning error surface (`is_dropped`, `is_poisoned`) has no Crystal
  # equivalent and is omitted.
  class Reload < Layer
    @inner : Layer
    @mutex : Mutex

    # Wraps `inner`, returning the reloadable layer and a `Handle` that can swap
    # or mutate it at runtime. Mirrors upstream `reload::Layer::new`.
    def self.new(inner : Layer) : {Reload, Handle}
      layer = new(inner, Mutex.new(:reentrant))
      {layer, Handle.new(layer)}
    end

    private def initialize(@inner : Layer, @mutex : Mutex)
    end

    # Returns an additional `Handle` that can reload this layer. Mirrors
    # upstream `reload::Layer::handle`.
    def handle : Handle
      Handle.new(self)
    end

    # ---- Layer delegation (to the current inner layer) ----

    def on_event(event : Core::Event, ctx : LayerContext) : Nil
      current.on_event(event, ctx)
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      current.on_new_span(attrs, id, ctx)
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      current.on_enter(id, ctx)
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
      current.on_exit(id, ctx)
    end

    def on_close(id : Core::Span::Id, ctx : LayerContext) : Nil
      current.on_close(id, ctx)
    end

    def on_record(id : Core::Span::Id, values : Core::Span::Record, ctx : LayerContext) : Nil
      current.on_record(id, values, ctx)
    end

    def on_record_follows_from(span : Core::Span::Id, follows : Core::Span::Id, ctx : LayerContext) : Nil
      current.on_record_follows_from(span, follows, ctx)
    end

    def on_register_callsite(metadata : Metadata, ctx : LayerContext) : Callsite::Interest
      current.on_register_callsite(metadata, ctx)
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      current.enabled?(metadata, ctx)
    end

    def max_level_hint : LevelFilter?
      current.max_level_hint
    end

    # ---- Reload operations (driven by Handle) ----

    protected def reload_inner(new_layer : Layer) : Nil
      @mutex.synchronize { @inner = new_layer }
    end

    protected def modify_inner(& : Layer ->) : Nil
      @mutex.synchronize { yield @inner }
    end

    protected def with_current_inner(& : Layer -> T) : T forall T
      @mutex.synchronize { yield @inner }
    end

    # Returns the current inner layer reference under the lock; the delegated
    # call then runs without holding the lock.
    private def current : Layer
      @mutex.synchronize { @inner }
    end
  end

  # Allows reloading the inner layer of an associated `Reload`.
  #
  # Ported from upstream `tracing_subscriber::reload::Handle`.
  class Handle
    @layer : Reload

    def initialize(@layer : Reload)
    end

    # Replaces the current layer with `new_value`.
    def reload(new_value : Layer) : Nil
      @layer.reload_inner(new_value)
    end

    # Invokes a block with the current layer, allowing in-place modification.
    def modify(& : Layer ->) : Nil
      @layer.modify_inner { |inner| yield inner }
    end

    # Invokes a block with a borrowed reference to the current layer and returns
    # the block's result.
    def with_current(& : Layer -> T) : T forall T
      @layer.with_current_inner { |inner| yield inner }
    end
  end
end
