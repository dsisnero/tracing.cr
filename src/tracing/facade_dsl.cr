module Tracing
  # Create a new span with the current subscriber.
  #
  # Usage:
  #   span = Tracing.span(Level::INFO, "my_span", answer: 42)
  #   span.in_scope { do_work }
  def self.span(level : Level, name : String, *, target : String? = nil, **fields) : Span
    meta = Metadata.new(name, target || name, level, kind: Kind::SPAN)
    values = build_field_valueset(fields)
    s = Span.new(meta, values)
    s
  end

  # Create a new span as a child of the given parent span ID.
  def self.child_span(parent_id : Core::Span::Id, level : Level, name : String, **fields) : Span
    meta = Metadata.new(name, name, level, kind: Kind::SPAN)
    values = build_field_valueset(fields)
    Span.child_of(parent_id, meta, values)
  end

  # Dispatch an event with the current subscriber.
  #
  # Usage:
  #   Tracing.event(Level::INFO, "my_event", key: "value")
  def self.event(level : Level, name : String, *, target : String? = nil, **fields) : Nil
    meta = Metadata.new(name, target || name, level, kind: Kind::EVENT)
    dispatch = Dispatch.current
    return unless dispatch
    return unless dispatch.enabled(meta)

    values = build_field_valueset(fields)
    event = Event.new(meta, values)
    dispatch.event(event)
  end

  # Level shorthand: dispatch an event at INFO level.
  def self.info(name : String, **fields) : Nil
    event(Level::INFO, name, **fields)
  end

  # Level shorthand: dispatch an event at TRACE level.
  def self.trace(name : String, **fields) : Nil
    event(Level::TRACE, name, **fields)
  end

  # Level shorthand: dispatch an event at DEBUG level.
  def self.debug(name : String, **fields) : Nil
    event(Level::DEBUG, name, **fields)
  end

  # Level shorthand: dispatch an event at WARN level.
  def self.warn(name : String, **fields) : Nil
    event(Level::WARN, name, **fields)
  end

  # Level shorthand: dispatch an event at ERROR level.
  def self.error(name : String, **fields) : Nil
    event(Level::ERROR, name, **fields)
  end

  # Wrap a block in a span context.
  #
  # Ported from upstream `#[instrument]` attribute.
  #
  # Usage:
  #   Tracing.instrument("my_func", arg: value) do
  #     # work happens inside span "my_func"
  #   end
  def self.instrument(name : String, **fields, & : -> T) : T forall T
    s = span(Level::INFO, name, **fields)
    s.in_scope { yield }
  end

  # Build a Field::ValueSet from named tuple fields.
  private def self.build_field_valueset(fields : NamedTuple) : Field::ValueSet
    names = fields.keys.to_a.map { |k| k.to_s.as(String) }
    fs = Field::FieldSet.of(names, Callsite::Identifier.new)
    vs = Field::ValueSet.new(fs)
    fields.each do |key, value|
      field = Field::Field.new(key.to_s)
      vs.record(field, value)
    end
    vs
  end
end
