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
end
