module Tracing
  # A type map of span extensions.
  class Extensions
    @map : Hash(String, Pointer(Void))

    def initialize
      @map = Hash(String, Pointer(Void)).new
    end

    def insert(value : T) : Nil forall T
      existing = replace(value)
      raise "Extensions: type #{T} already present" unless existing.nil?
    end

    def replace(value : T) : T? forall T
      key = T.name
      old = get(T)
      ptr = Pointer(typeof(value)).malloc(1_u64)
      ptr.value = value
      @map[key] = ptr.as(Pointer(Void))
      old
    end

    def get(type : T.class) : T? forall T
      key = T.name
      void_ptr = @map[key]?
      return unless void_ptr
      typed_ptr = void_ptr.as(Pointer(T))
      typed_ptr.value
    end

    def remove(type : T.class) : T? forall T
      key = T.name
      old = get(T)
      @map.delete(key)
      old
    end
  end

  class ExtensionsMut
    @inner : Extensions

    def initialize(@inner : Extensions)
    end

    def insert(value) : Nil
      @inner.insert(value)
    end

    def replace(value) : T? forall T
      @inner.replace(value)
    end

    def remove(type : T.class) : T? forall T
      @inner.remove(type)
    end

    def get(type : T.class) : T? forall T
      @inner.get(type)
    end
  end
end
