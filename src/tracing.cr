require "./tracing/types"
require "./tracing/field"
require "./tracing/metadata"
require "./tracing/callsite"
require "./tracing/span"
require "./tracing/event"
require "./tracing/subscriber"
require "./tracing/dispatcher"
require "./tracing/facade_span"

module Tracing
  VERSION = "0.1.0"

  alias Level = Core::Level
  alias LevelFilter = Core::LevelFilter
  alias ParseLevelError = Core::ParseLevelError
  alias ParseLevelFilterError = Core::ParseLevelFilterError
  alias Kind = Core::Kind
  alias Metadata = Core::Metadata
  alias Parent = Core::Parent
  alias Event = Core::Event
  alias Dispatch = Core::Dispatch

  module CoreSpan
    alias Id = Core::Span::Id
    alias Attributes = Core::Span::Attributes
    alias Record = Core::Span::Record
    alias Current = Core::Span::Current
  end

  module Field
    alias Field = Core::Field::Field
    alias FieldSet = Core::Field::FieldSet
    alias ValueSet = Core::Field::ValueSet
    alias Visit = Core::Field::Visit
  end

  module Callsite
    alias Identifier = Core::Callsite::Identifier
    alias Interest = Core::Callsite::Interest
    alias Interface = Core::Callsite::Interface
    alias DefaultCallsite = Core::Callsite::DefaultCallsite
  end
end
