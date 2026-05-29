module Tracing
  # A handle representing a span.
  class Span
    @inner : Inner?
    @meta : Metadata?

    record Inner, id : Core::Span::Id, subscriber : Dispatch

    protected def initialize(@inner : Inner?, @meta : Metadata?)
    end

    # Creates a new span with the current subscriber and parent.
    def self.new(meta : Metadata, values : Field::ValueSet = Field::ValueSet.new) : self
      dispatch = Dispatch.current
      inner = nil
      if dispatch && dispatch.enabled(meta)
        attrs = Core::Span::Attributes.new(meta, values)
        id = dispatch.new_span(attrs)
        inner = Inner.new(id, dispatch)
      end
      new(inner, meta)
    end

    def self.new_root(meta : Metadata, values : Field::ValueSet = Field::ValueSet.new) : self
      dispatch = Dispatch.current
      inner = nil
      if dispatch && dispatch.enabled(meta)
        attrs = Core::Span::Attributes.new(meta, values, parent: Parent::ROOT)
        id = dispatch.new_span(attrs)
        inner = Inner.new(id, dispatch)
      end
      new(inner, meta)
    end

    def self.child_of(parent_id : Core::Span::Id, meta : Metadata, values : Field::ValueSet = Field::ValueSet.new) : self
      dispatch = Dispatch.current
      inner = nil
      if dispatch && dispatch.enabled(meta)
        attrs = Core::Span::Attributes.new(meta, values, parent: Parent.explicit(parent_id))
        id = dispatch.new_span(attrs)
        inner = Inner.new(id, dispatch)
      end
      new(inner, meta)
    end

    def disabled? : Bool
      @inner.nil?
    end

    def enter : Entered
      if inner = @inner
        inner.subscriber.enter(inner.id)
        return Entered.new(self)
      end
      Entered.new(self)
    end

    def entered : EnteredSpan
      enter_span
      EnteredSpan.new(self)
    end

    def in_scope(& : -> T) : T forall T
      guard = enter
      begin
        yield
      ensure
        guard.exit
      end
    end

    def record(field : Field::Field, value) : Nil
      return unless inner = @inner
      vs = Field::ValueSet.new
      vs.record(field, value)
      inner.subscriber.record(inner.id, Core::Span::Record.new(vs))
    end

    def follows_from(from : Core::Span::Id) : Nil
      return unless inner = @inner
      inner.subscriber.record_follows_from(inner.id, from)
    end

    def id : Core::Span::Id?
      @inner.try(&.id)
    end

    def metadata : Metadata?
      @meta
    end

    def exit_span : Nil
      if inner = @inner
        inner.subscriber.exit(inner.id)
      end
    end
  end

  class Entered
    @span : Span
    @exited : Bool

    def initialize(@span : Span)
      @exited = false
    end

    def exit : Span
      return @span if @exited
      @span.exit_span
      @exited = true
      @span
    end
  end

  class EnteredSpan
    @span : Span
    @exited : Bool

    def initialize(span : Span)
      @span = span
      @exited = false
    end

    def exit : Span
      return @span if @exited
      @span.exit_span
      @exited = true
      @span
    end

    def finalize
      return if @exited
      @span.exit_span
    end
  end
end
