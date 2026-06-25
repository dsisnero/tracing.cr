require "./tracing/core/types"
require "./tracing/core/field"
require "./tracing/core/metadata"
require "./tracing/core/callsite"
require "./tracing/core/span"
require "./tracing/core/event"
require "./tracing/core/subscriber"
require "./tracing/core/dispatcher"
require "./tracing/facade_span"
require "./tracing/facade_dsl"
require "./tracing/facade_macros"
require "./tracing/subscriber/registry"
require "./tracing/subscriber/layer"
require "./tracing/subscriber/lookup_span"
require "./tracing/subscriber/extensions"
require "./tracing/subscriber/filter"
require "./tracing/subscriber/fmt"
require "./tracing/subscriber/fmt/time"
require "./tracing/subscriber/env_filter"
require "./tracing/subscriber/filter_fn"
require "./tracing/subscriber/targets"
require "./tracing/subscriber/reload"
require "./tracing/subscriber/log_tracer"
require "./tracing/subscriber/appender"
require "./tracing/subscriber/mock"
require "./tracing/subscriber/span_trace"
require "./tracing/subscriber/flame"
require "./tracing/opentelemetry/layer"
require "./tracing/subscriber_conv"

module Tracing
  VERSION = "0.5.1"

  def self.fmt_layer : FmtLayer
    FmtLayer.new
  end

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
