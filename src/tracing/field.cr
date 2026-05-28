module Tracing
  module Core
    module Field
      # A named field.
      struct Field
        getter name : String

        def initialize(@name : String = "")
        end

        def ==(other : Field) : Bool
          @name == other.@name
        end

        def to_s(io : IO) : Nil
          io << @name
        end
      end

      # A set of field names, ordered by declaration index.
      struct FieldSet
        getter fields : Array(Field)
        @callsite_id : Pointer(Void)

        def self.of(field_names : Enumerable(String), callsite : Callsite::Identifier)
          fields = field_names.map { |n| Field.new(n) }.to_a
          new(fields, callsite.ptr)
        end

        def initialize(@fields : Array(Field) = [] of Field, @callsite_id : Pointer(Void) = Pointer(Void).null)
        end

        def callsite : Callsite::Identifier
          Callsite::Identifier.new(@callsite_id)
        end

        def fake_field : Field
          Field.new
        end

        def empty? : Bool
          @fields.empty?
        end

        def size : Int32
          @fields.size
        end

        def [](index : Int32) : Field
          @fields[index]
        end

        def each(&) : Nil
          @fields.each { |f| yield f }
        end

        def ==(other : FieldSet) : Bool
          @fields == other.@fields
        end

        def to_s(io : IO) : Nil
          io << @fields.map(&.name).join(", ")
        end
      end

      # Trait for visiting typed field values.
      module Visit
        abstract def record_debug(field : Field, value) : Nil
        abstract def record_i64(field : Field, value : Int64) : Nil
        abstract def record_u64(field : Field, value : UInt64) : Nil
        abstract def record_f64(field : Field, value : Float64) : Nil
        abstract def record_bool(field : Field, value : Bool) : Nil
        abstract def record_str(field : Field, value : String) : Nil
        abstract def record_error(field : Field, value : Exception) : Nil
      end

      # A set of recorded field values paired with a FieldSet.
      class ValueSet
        getter fields : FieldSet
        @values : Array(FieldValue)

        def initialize(@fields : FieldSet = FieldSet.new)
          @values = [] of FieldValue
        end

        def record(field : Field, value : _) : Nil
          @values << FieldValue.new(field, value)
        end

        def record(field : Field, value : Int) : Nil
          @values << FieldValue.i64(field, value.to_i64)
        end

        def record(field : Field, value : String) : Nil
          @values << FieldValue.str(field, value)
        end

        def record(field : Field, value : Bool) : Nil
          @values << FieldValue.bool(field, value)
        end

        def record(field : Field, value : Float) : Nil
          @values << FieldValue.f64(field, value.to_f64)
        end

        def record(field : Field, value : Exception) : Nil
          @values << FieldValue.error(field, value)
        end

        def is_empty? : Bool
          @values.empty?
        end

        def visit(visitor : Visit) : Nil
          @values.each(&.record(visitor))
        end

        def to_s(io : IO) : Nil
          io << "ValueSet{"
          @values.join(", ", io)
          io << "}"
        end
      end

      private class FieldValue
        getter field : Field
        @tag : Symbol
        @i64_val : Int64 = 0_i64
        @u64_val : UInt64 = 0_u64
        @f64_val : Float64 = 0.0
        @bool_val : Bool = false
        @str_val : String = ""
        @error_val : Exception?
        @debug_val : NoReturn?

        def self.i64(field : Field, value : Int64) : self
          v = new(field, :i64)
          v.set_i64(value)
          v
        end

        def self.u64(field : Field, value : UInt64) : self
          v = new(field, :u64)
          v.set_u64(value)
          v
        end

        def self.f64(field : Field, value : Float64) : self
          v = new(field, :f64)
          v.set_f64(value)
          v
        end

        def self.bool(field : Field, value : Bool) : self
          v = new(field, :bool)
          v.set_bool(value)
          v
        end

        def self.str(field : Field, value : String) : self
          v = new(field, :str)
          v.set_str(value)
          v
        end

        def self.error(field : Field, value : Exception) : self
          v = new(field, :error)
          v.set_error(value)
          v
        end

        def self.debug(field : Field, value) : self
          v = new(field, :debug)
          v.set_debug(value)
          v
        end

        private def initialize(@field : Field, @tag : Symbol)
        end

        protected def set_i64(value : Int64)
          @i64_val = value
        end

        protected def set_u64(value : UInt64)
          @u64_val = value
        end

        protected def set_f64(value : Float64)
          @f64_val = value
        end

        protected def set_bool(value : Bool)
          @bool_val = value
        end

        protected def set_str(value : String)
          @str_val = value
        end

        protected def set_error(value : Exception)
          @error_val = value
        end

        protected def set_debug(value)
          @debug_val = value
        end

        def record(visitor : Visit) : Nil
          case @tag
          when :i64   then visitor.record_i64(@field, @i64_val)
          when :u64   then visitor.record_u64(@field, @u64_val)
          when :f64   then visitor.record_f64(@field, @f64_val)
          when :bool  then visitor.record_bool(@field, @bool_val)
          when :str   then visitor.record_str(@field, @str_val)
          when :error then visitor.record_error(@field, @error_val.not_nil!)
          when :debug then visitor.record_debug(@field, @debug_val)
          end
        end

        def to_s(io : IO) : Nil
          case @tag
          when :i64   then io << @i64_val
          when :u64   then io << @u64_val
          when :f64   then io << @f64_val
          when :bool  then io << @bool_val
          when :str   then io << @str_val
          when :error then io << @error_val
          when :debug then io << @debug_val
          end
        end
      end
    end
  end
end
