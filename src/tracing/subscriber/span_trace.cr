module Tracing
  # A captured trace of the current tracing span context.
  #
  # Useful for enriching errors with the span stack at the point
  # where the error occurred.
  #
  # Ported from upstream `tracing_error::SpanTrace`.
  class SpanTrace
    getter spans : Array(String)

    def initialize(@spans : Array(String) = [] of String)
    end

    # Capture the current span stack from a Registry.
    def self.capture(registry : Registry) : self
      spans = [] of String
      # Walk the current span stack (innermost first)
      stack = registry.current_span_stack
      stack.reverse_each do |id|
        data = registry.span_data(id)
        spans << data.name if data
      end
      new(spans)
    end

    def to_s(io : IO) : Nil
      @spans.each_with_index do |name, i|
        io << "  " unless i == 0
        io << "in span: " << name
      end
    end

    def to_s : String
      String.build { |io| to_s(io) }
    end
  end
end
