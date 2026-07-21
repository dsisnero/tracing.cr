require "json"

module Tracing
  module FmtFormat
    class JsonVisitor
      include Core::Field::Visit
      include FmtField::VisitFmt
      include FmtField::VisitOutput

      getter writer : IO
      getter values : Hash(String, JSON::Any)

      def initialize(@writer : IO)
        @values = {} of String => JSON::Any
      end

      def finish : Nil
        builder = JSON::Builder.new(@writer)
        builder.start_document
        builder.object do
          @values.each do |key, value|
            builder.field(key, value)
          end
        end
        builder.end_document
      end

      def record_debug(field : Field::Field, value) : Nil
        @values[field.name] = JSON::Any.new(value.to_s)
      end

      def record_i64(field : Field::Field, value : Int64) : Nil
        @values[field.name] = JSON::Any.new(value)
      end

      def record_u64(field : Field::Field, value : UInt64) : Nil
        @values[field.name] = JSON::Any.new(value)
      end

      def record_f64(field : Field::Field, value : Float64) : Nil
        @values[field.name] = JSON::Any.new(value)
      end

      def record_bool(field : Field::Field, value : Bool) : Nil
        @values[field.name] = JSON::Any.new(value)
      end

      def record_str(field : Field::Field, value : String) : Nil
        @values[field.name] = JSON::Any.new(value)
      end

      def record_error(field : Field::Field, value : Exception) : Nil
        @values[field.name] = JSON::Any.new(value.message || "")
      end
    end

    class JsonFields < FormatFields
      include FmtField::MakeVisitor(Writer)

      def make_visitor(target : Writer) : Core::Field::Visit
        JsonVisitor.new(target.io)
      end

      def format_fields(writer : Writer, values : Field::ValueSet) : Nil
        visitor = make_visitor(writer)
        values.visit(visitor)
        visitor.as(JsonVisitor).finish
      end
    end
  end
end
