module Tracing
  # A handle representing a span.
  #
  # If the span was rejected by the current subscriber's filter,
  # entering the span will silently do nothing.
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
      if dispatch && meta.level <= (dispatch.max_level_hint || LevelFilter.trace)
        attrs = Core::Span::Attributes.new(meta, values)
        id = dispatch.new_span(attrs)
        inner = Inner.new(id, dispatch)
      end
      new(inner, meta)
    end

    # Creates a new span as a root (no parent).
    def self.new_root(meta : Metadata, values : Field::ValueSet = Field::ValueSet.new) : self
      dispatch = Dispatch.current
      inner = nil
      if dispatch && meta.level <= (dispatch.max_level_hint || LevelFilter.trace)
        attrs = Core::Span::Attributes.new(meta, values, parent: Parent::ROOT)
        id = dispatch.new_span(attrs)
        inner = Inner.new(id, dispatch)
      end
      new(inner, meta)
    end

    # Creates a new span as child of the given parent.
    def self.child_of(parent_id : Core::Span::Id, meta : Metadata, values : Field::ValueSet = Field::ValueSet.new) : self
      dispatch = Dispatch.current
      inner = nil
      if dispatch && meta.level <= (dispatch.max_level_hint || LevelFilter.trace)
        attrs = Core::Span::Attributes.new(meta, values, parent: Parent.explicit(parent_id))
        id = dispatch.new_span(attrs)
        inner = Inner.new(id, dispatch)
      end
      new(inner, meta)
    end

    # Returns true if this span is disabled (rejected by subscriber filter).
    def disabled? : Bool
      @inner.nil?
    end

    # Enter this span, returning a guard that exits on drop.
    #
    # Usage:
    #   span = Span.new(meta)
    #   _guard = span.enter  # span is now entered
    #   # work happens here
    #   # guard dropped → span exited
    def enter : Entered
      if inner = @inner
        inner.subscriber.enter(inner.id)
        return Entered.new(self)
      end
      Entered.new(self)
    end

    # Enter this span, returning an owned guard.
    def entered : EnteredSpan
      enter_span
      EnteredSpan.new(self)
    end

    # Execute a block inside this span.
    def in_scope(& : -> T) : T forall T
      guard = enter
      begin
        yield
      ensure
        guard.exit
      end
    end

    # Record fields on this span.
    def record(field : Field::Field, value) : Nil
      return unless inner = @inner
      vs = Field::ValueSet.new
      vs.record(field, value)
      inner.subscriber.record(inner.id, Core::Span::Record.new(vs))
    end

    # Record that this span follows from another.
    def follows_from(from : Core::Span::Id) : Nil
      return unless inner = @inner
      inner.subscriber.record_follows_from(inner.id, from)
    end

    # Returns the span's ID, if enabled.
    def id : Core::Span::Id?
      @inner.try(&.id)
    end

    # Returns the span's metadata.
    def metadata : Metadata?
      @meta
    end

    # Called when the guard exits the span.
    def exit_span : Nil
      if inner = @inner
        inner.subscriber.exit(inner.id)
      end
    end
  end

  # A guard that exits a span when dropped.
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

    def finalize
      @span.exit_span unless @exited
    end

    # Explicitly exit the span, returning it.
    def exit : Span
      @span.exit_span
      @span
    end
  end

  # An owned guard that exits a span when dropped.
  #
  # Returned by `Span#entered`.
  class EnteredSpan
    @span : Span
    @exited : Bool

    def initialize(span : Span)
      @span = span
      @exited = false
    end

    # Explicitly exit and return the span.
    def exit : Span
      return @span if @exited
      @span.exit_span
      @exited = true
      @span
    end

    # Auto-exit on finalize (drop guard).
    def finalize
      return if @exited
      @span.exit_span
    end
  end
end
