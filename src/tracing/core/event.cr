module Tracing
  module Core
    # Represents a single event within a trace.
    class Event
      getter metadata : Metadata
      getter values : Field::ValueSet
      getter parent : Parent

      def initialize(
        @metadata : Metadata,
        @values : Field::ValueSet = Field::ValueSet.new,
        @parent : Parent = Parent::CURRENT,
      )
      end

      def dispatch : Bool
        false
      end

      def root? : Bool
        @parent.root?
      end

      def contextual? : Bool
        @parent.current?
      end

      def has_explicit_parent? : Bool
        @parent.explicit?
      end

      def to_s(io : IO) : Nil
        io << "Event{metadata: #{@metadata}, parent: #{@parent}}"
      end

      def record(visitor : Field::Visit) : Nil
        @values.visit(visitor)
      end
    end
  end
end
