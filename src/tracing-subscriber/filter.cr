module Tracing
  # A Layer that filters based on verbosity level.
  #
  # Ported from upstream `tracing_subscriber::filter::LevelFilter`.
  class LevelFilterLayer < Layer
    @filter : LevelFilter

    def initialize(@filter : LevelFilter)
    end

    def on_register_callsite(metadata : Metadata, ctx : LayerContext) : Callsite::Interest
      if metadata.level <= @filter
        Callsite::Interest.always
      else
        Callsite::Interest.never
      end
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      metadata.level <= @filter
    end

    def max_level_hint : LevelFilter?
      @filter
    end
  end

  # Open Layered to support chaining .with
  class Layered(S)
    def with(layer : Layer) : Layered(Layered(S))
      Layered.new(self, layer)
    end
  end
end
