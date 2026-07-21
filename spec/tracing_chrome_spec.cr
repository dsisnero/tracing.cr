require "spec"

require "../src/tracing/core/types"
require "../src/tracing/core/field"
require "../src/tracing/core/metadata"
require "../src/tracing/core/callsite"
require "../src/tracing/core/span"
require "../src/tracing/core/event"
require "../src/tracing/core/subscriber"
require "../src/tracing/core/dispatcher"
require "../src/tracing/facade_span"
require "../src/tracing/facade_dsl"
require "../src/tracing/facade_macros"
require "../src/tracing/subscriber/registry"
require "../src/tracing/subscriber/layer"
require "../src/tracing/subscriber/lookup_span"
require "../src/tracing/subscriber/extensions"
require "../src/tracing/subscriber/filter"
require "../src/tracing/subscriber/env_filter"
require "../src/tracing/subscriber/filter_fn"
require "../src/tracing/subscriber/filter_ext"
require "../src/tracing/subscriber/targets"
require "../src/tracing/subscriber/mock"

require "../src/tracing"
require "../src/tracing/subscriber/fmt/time"
require "../src/tracing/subscriber/fmt/format"
require "../src/tracing/subscriber/log_tracer"
require "../src/tracing/subscriber/appender"
require "../src/tracing/subscriber/span_trace"
require "../src/tracing/subscriber/flame"
require "../src/tracing/subscriber/reload"
require "../src/tracing/subscriber/fmt_builder"
require "../src/tracing/subscriber_conv"

require "../src/tracing/chrome"

module Tracing
  describe TraceStyle do
    it "has Threaded variant" do
      TraceStyle::Threaded.should be_a(TraceStyle)
    end

    it "has Async variant" do
      TraceStyle::Async.should be_a(TraceStyle)
    end

    it "Threaded is the first variant (default)" do
      TraceStyle.values.first.should eq(TraceStyle::Threaded)
    end
  end

  describe ChromeLayerBuilder do
    it "can be instantiated" do
      builder = ChromeLayerBuilder.new
      builder.should be_a(ChromeLayerBuilder)
    end

    it "sets writer" do
      io = IO::Memory.new
      builder = ChromeLayerBuilder.new.writer(io)
      builder.should be_a(ChromeLayerBuilder)
    end

    it "sets include_args" do
      builder = ChromeLayerBuilder.new.include_args(true)
      builder.should be_a(ChromeLayerBuilder)
    end

    it "sets include_locations" do
      builder = ChromeLayerBuilder.new.include_locations(false)
      builder.should be_a(ChromeLayerBuilder)
    end

    it "sets trace_style" do
      builder = ChromeLayerBuilder.new.trace_style(TraceStyle::Async)
      builder.should be_a(ChromeLayerBuilder)
    end

    it "sets file (path string)" do
      builder = ChromeLayerBuilder.new.file("/tmp/test_trace.json")
      builder.should be_a(ChromeLayerBuilder)
    end

    it "sets name_fn" do
      fn = ->(_e : EventOrSpan) { "test_name" }
      builder = ChromeLayerBuilder.new.name_fn(fn)
      builder.should be_a(ChromeLayerBuilder)
    end

    it "sets category_fn" do
      fn = ->(_e : EventOrSpan) { "test_cat" }
      builder = ChromeLayerBuilder.new.category_fn(fn)
      builder.should be_a(ChromeLayerBuilder)
    end
  end

  describe ChromeLayer do
    it "can be instantiated with builder" do
      io = IO::Memory.new
      layer, guard = ChromeLayerBuilder.new.writer(io).build
      layer.should be_a(ChromeLayer)
      guard.should be_a(FlushGuard)
    end

    it "produces valid JSON trace output with spans and events" do
      io = IO::Memory.new
      layer, guard = ChromeLayerBuilder.new.writer(io).build
      registry = Registry.new
      subscriber = registry.with(layer)

      meta = Metadata.new("test_span", "test_target", Level::INFO)
      id = subscriber.new_span(Core::Span::Attributes.new(meta))
      subscriber.enter(id)
      subscriber.exit(id)
      subscriber.try_close(id)

      event_meta = Metadata.new("test_event", "my_target", Level::INFO)
      subscriber.event(Core::Event.new(event_meta))

      guard.flush

      output = io.to_s
      output.should contain("test_span")
      output.should contain("test_event")
      output.should contain("test_target")
      output.should contain("my_target")
      output.should contain("B")
      output.should contain("E")
      output.should contain("i")
    end

    it "includes args when configured" do
      io = IO::Memory.new
      fields = Core::Field::FieldSet.of(["key1"], Callsite::Identifier.new(Pointer(Void).null))
      values = Core::Field::ValueSet.new(fields)
      values.record(Core::Field::Field.new("key1"), "val1")

      layer, guard = ChromeLayerBuilder.new.writer(io).include_args(true).build
      registry = Registry.new
      subscriber = registry.with(layer)

      meta = Metadata.new("test_span", "test_target", Level::INFO)
      id = subscriber.new_span(Core::Span::Attributes.new(meta, values))
      subscriber.exit(id)
      subscriber.try_close(id)

      guard.flush
      output = io.to_s
      output.should contain("key1")
    end

    it "includes locations when configured" do
      io = IO::Memory.new
      layer, guard = ChromeLayerBuilder.new.writer(io).include_locations(true).build
      registry = Registry.new
      subscriber = registry.with(layer)

      meta = Metadata.new("loc_test", "target", Level::INFO, file: "source.cr", line: 99)
      id = subscriber.new_span(Core::Span::Attributes.new(meta))
      subscriber.enter(id)
      subscriber.exit(id)
      subscriber.try_close(id)

      guard.flush
      output = io.to_s
      output.should contain("source.cr")
      output.should contain("99")
    end
  end

  describe FlushGuard do
    it "flushes output" do
      io = IO::Memory.new
      _layer, guard = ChromeLayerBuilder.new.writer(io).build
      guard.flush
    end

    it "finalizes cleanly" do
      io = IO::Memory.new
      _layer, guard = ChromeLayerBuilder.new.writer(io).build
      guard.finalize
    end
  end
end
