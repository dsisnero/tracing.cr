module Tracing
  module Core
    # Metadata describing a span or event.
    #
    # All spans and events have the following metadata:
    # - A name, represented as a static string.
    # - A target, a string that categorizes part of the system.
    # - A verbosity level.
    # - The names of the fields defined by the span or event.
    # - Whether the metadata corresponds to a span or event.
    #
    # Optional metadata: file name, line number, module path.
    struct Metadata
      getter name : String
      getter target : String
      getter level : Level
      getter module_path : String?
      getter file : String?
      getter line : UInt32?
      getter fields : Field::FieldSet
      getter kind : Kind

      def initialize(
        @name : String,
        @target : String,
        @level : Level,
        @file : String? = nil,
        @line : UInt32? = nil,
        @module_path : String? = nil,
        @fields : Field::FieldSet = Field::FieldSet.new,
        @kind : Kind = Kind::SPAN,
      )
      end

      def callsite : Callsite::Identifier
        @fields.callsite
      end

      def is_event? : Bool
        @kind.is_event?
      end

      def is_span? : Bool
        @kind.is_span?
      end

      def private_fake_field : Field::Field
        @fields.fake_field
      end

      def ==(other : Metadata) : Bool
        object_id == other.object_id || callsite == other.callsite
      end

      def to_s(io : IO) : Nil
        io << "Metadata{"
        io << "name: #{@name}, "
        io << "target: #{@target}, "
        io << "level: #{@level}"
        case {file, line}
        when {String, UInt32}
          io << ", location: #{@file}:#{@line}"
        when {String, Nil}
          io << ", file: #{@file}"
        when {Nil, UInt32}
          io << ", line: #{@line}"
        end
        if path = @module_path
          io << ", module_path: #{path}"
        end
        io << ", fields: #{@fields}"
        io << ", callsite: #{callsite}"
        io << ", kind: #{@kind}"
        io << "}"
      end
    end
  end
end
