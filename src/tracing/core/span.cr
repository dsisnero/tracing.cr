module Tracing
  module Core
    # The parent of a span: Root, Current, or Explicit(id).
    class Parent
      private enum Kind
        ROOT
        CURRENT
        EXPLICIT
      end

      ROOT    = new(Kind::ROOT)
      CURRENT = new(Kind::CURRENT)

      getter id : Span::Id?

      private def initialize(@kind : Kind, @id : Span::Id? = nil)
      end

      def self.explicit(span_id : Span::Id) : self
        new(Kind::EXPLICIT, id: span_id)
      end

      def root? : Bool
        @kind.root?
      end

      def current? : Bool
        @kind.current?
      end

      def explicit? : Bool
        @kind.explicit?
      end

      def ==(other : Parent) : Bool
        @kind == other.@kind && @id == other.@id
      end

      def to_s(io : IO) : Nil
        case @kind
        in .root?     then io << "Root"
        in .current?  then io << "Current"
        in .explicit? then io << "Explicit(#{@id})"
        end
      end
    end

    module Span
      # Identifies a span within the context of a subscriber.
      struct Id
        getter id : UInt64

        def self.from_u64(u : UInt64) : self
          raise ArgumentError.new("span IDs must be > 0") if u == 0
          new(u)
        end

        def initialize(@id : UInt64)
          raise ArgumentError.new("span IDs must be > 0") if @id == 0
        end

        def into_u64 : UInt64
          @id
        end

        def ==(other : Id) : Bool
          @id == other.@id
        end

        def hash(hasher)
          @id.hash(hasher)
        end

        def to_s(io : IO) : Nil
          io << @id
        end
      end

      # Attributes provided to a Subscriber describing a new span.
      struct Attributes
        getter metadata : Metadata
        getter values : Field::ValueSet
        getter parent : Parent

        def initialize(@metadata : Metadata, @values : Field::ValueSet = Field::ValueSet.new, @parent : Parent = Parent::CURRENT)
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
          io << "Attributes{metadata: #{@metadata}, parent: #{@parent}}"
        end
      end

      # A set of fields recorded by a span.
      struct Record
        getter values : Field::ValueSet

        def initialize(@values : Field::ValueSet = Field::ValueSet.new)
        end

        def to_s(io : IO) : Nil
          io << "Record{#{@values}}"
        end
      end

      # Indicates what the Subscriber considers the "current" span.
      class Current
        private enum Kind
          CURRENT
          NONE
          UNKNOWN
        end

        @kind : Kind
        @id : Id?
        @metadata : Metadata?

        private def initialize(@kind : Kind, @id : Id? = nil, @metadata : Metadata? = nil)
        end

        def self.current(id : Id, metadata : Metadata) : self
          new(Kind::CURRENT, id: id, metadata: metadata)
        end

        def self.none : self
          new(Kind::NONE)
        end

        def self.unknown : self
          new(Kind::UNKNOWN)
        end

        def current? : Bool
          @kind == Kind::CURRENT
        end

        def none? : Bool
          @kind == Kind::NONE
        end

        def unknown? : Bool
          @kind == Kind::UNKNOWN
        end

        def id : Id?
          @id
        end

        def metadata : Metadata?
          @metadata
        end

        def to_s(io : IO) : Nil
          case @kind
          in .current? then io << "Current(#{@id})"
          in .none?    then io << "None"
          in .unknown? then io << "Unknown"
          end
        end
      end
    end
  end
end
