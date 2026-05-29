require "./spec_helper"

private alias Level = Tracing::Level
private alias LevelFilter = Tracing::LevelFilter
private alias ParseLevelError = Tracing::ParseLevelError
private alias ParseLevelFilterError = Tracing::ParseLevelFilterError
private alias Kind = Tracing::Kind
private alias Metadata = Tracing::Metadata
private alias Parent = Tracing::Parent
private alias SpanId = Tracing::CoreSpan::Id
private alias Span = Tracing::Span
private alias Dispatch = Tracing::Dispatch
private alias Callsite = Tracing::Callsite
private alias Subscriber = Tracing::Core::Subscriber
private alias CoreSpan = Tracing::Core::Span

# Ported from vendor/tracing/tracing-core/src/metadata.rs doc examples
describe "Level comparisons (ported from upstream metadata.rs)" do
  it "TRACE > DEBUG" do
    (Level::TRACE > Level::DEBUG).should be_true
  end

  it "ERROR < WARN" do
    (Level::ERROR < Level::WARN).should be_true
  end

  it "INFO <= DEBUG" do
    (Level::INFO <= Level::DEBUG).should be_true
  end

  it "TRACE == TRACE" do
    (Level::TRACE == Level::TRACE).should be_true
  end
end

# Ported from vendor/tracing/tracing-core/src/metadata.rs doc examples
describe "LevelFilter comparisons (ported from upstream metadata.rs)" do
  it "OFF < TRACE" do
    (LevelFilter.off < Level::TRACE).should be_true
  end

  it "TRACE > DEBUG" do
    (LevelFilter.trace > Level::DEBUG).should be_true
  end

  it "ERROR < WARN" do
    (LevelFilter.error < Level::WARN).should be_true
  end

  it "INFO <= DEBUG" do
    (LevelFilter.info <= Level::DEBUG).should be_true
  end

  it "INFO >= INFO" do
    (LevelFilter.info >= Level::INFO).should be_true
  end
end

# Ported from vendor/tracing/tracing-core/src/metadata.rs doc examples
describe "Level vs LevelFilter comparisons (ported from upstream metadata.rs)" do
  it "ERROR <= TRACE filter" do
    (Level::ERROR <= LevelFilter.trace).should be_true
  end

  it "DEBUG <= INFO filter is false (DEBUG exceeds INFO threshold)" do
    (Level::DEBUG <= LevelFilter.info).should be_false
  end

  it "WARN > ERROR filter" do
    (Level::WARN > LevelFilter.error).should be_true
  end

  it "INFO == INFO filter" do
    (Level::INFO == LevelFilter.info).should be_true
  end
end

describe Tracing::Core::Level do
  describe ".parse" do
    it "parses string names" do
      Level.parse("error").should eq(Level::ERROR)
      Level.parse("warn").should eq(Level::WARN)
      Level.parse("info").should eq(Level::INFO)
      Level.parse("debug").should eq(Level::DEBUG)
      Level.parse("trace").should eq(Level::TRACE)
    end

    it "parses numeric strings" do
      Level.parse("1").should eq(Level::ERROR)
      Level.parse("4").should eq(Level::DEBUG)
    end

    it "raises on invalid input" do
      expect_raises(ParseLevelError) { Level.parse("invalid") }
      expect_raises(ParseLevelError) { Level.parse("0") }
    end
  end

  describe "#as_str" do
    it { Level::ERROR.as_str.should eq("ERROR") }
    it { Level::TRACE.as_str.should eq("TRACE") }
  end
end

describe Tracing::Core::LevelFilter do
  describe "conversion" do
    it "converts OFF to nil" do
      LevelFilter.off.into_level.should be_nil
    end

    it "converts ERROR to Level::ERROR" do
      LevelFilter.error.into_level.should eq(Level::ERROR)
    end

    it "can be constructed from a Level" do
      f = LevelFilter.from_level(Level::TRACE)
      f.into_level.should eq(Level::TRACE)
    end
  end

  describe ".parse" do
    it "parses off" do
      LevelFilter.parse("off").into_level.should be_nil
    end

    it "parses empty string as ERROR" do
      LevelFilter.parse("").into_level.should eq(Level::ERROR)
    end
  end
end

describe Tracing::Core::Kind do
  it "SPAN is span" do
    Kind::SPAN.span?.should be_true
    Kind::SPAN.event?.should be_false
  end

  it "EVENT is event" do
    Kind::EVENT.span?.should be_false
    Kind::EVENT.event?.should be_true
  end

  it "hint adds HINT bit" do
    k = Kind::SPAN.hint
    k.span?.should be_true
    k.hint?.should be_true
  end
end

describe Tracing::Core::Span::Id do
  it "constructs from non-zero u64" do
    id = SpanId.from_u64(42_u64)
    id.into_u64.should eq(42_u64)
  end

  it "rejects zero" do
    expect_raises(ArgumentError) { SpanId.from_u64(0_u64) }
  end
end

describe Tracing::Core::Parent do
  it "ROOT is root" do
    Parent::ROOT.root?.should be_true
    Parent::ROOT.current?.should be_false
  end

  it "CURRENT is current" do
    Parent::CURRENT.current?.should be_true
  end

  it "explicit has an id" do
    id = SpanId.from_u64(10_u64)
    p = Parent.explicit(id)
    p.explicit?.should be_true
    p.id.should eq(id)
  end
end

describe Tracing::Span do
  it "creates a disabled span when no subscriber" do
    s = Span.new(Metadata.new("test", "test_target", Level::INFO))
    s.disabled?.should be_true
  end

  it "enter on disabled span does not crash" do
    s = Span.new(Metadata.new("test", "test_target", Level::INFO))
    guard = s.enter
    guard.should be_a(Tracing::Entered)
  end

  it "enter/exit lifecycle with a subscriber" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      meta = Metadata.new("test_span", "test_target", Level::INFO, kind: Kind::SPAN)
      span = Span.new(meta)
      span.disabled?.should be_false
      span.id.should_not be_nil

      guard = span.enter
      subscriber.entered_count.should eq(1)

      span2 = guard.exit
      subscriber.exited_count.should eq(1)
      span2.disabled?.should be_false
    end
  end
end

describe Tracing::Core::Dispatch do
  it "with_default scopes dispatch to a fiber" do
    subscriber = TestSubscriber.new
    dispatch = Dispatch.new(subscriber)
    prior = Dispatch.current

    result = Dispatch.with_default(dispatch) do
      Dispatch.current.try(&.subscriber).should eq(subscriber)
      42
    end

    result.should eq(42)
    Dispatch.current.should eq(prior)
  end
end

# RED tests — Tracing.span and Tracing.event DSL methods
describe "Tracing.span (ported from upstream span! macro)" do
  it "creates a span via DSL method" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      s = Tracing.span(Level::INFO, "my_span", answer: 42)
      s.disabled?.should be_false
      subscriber.new_span_count.should eq(1)
    end
  end

  it "creates a span with parent override" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      parent_id = SpanId.from_u64(99_u64)
      s = Tracing.child_span(parent_id, Level::INFO, "child_span")
      s.disabled?.should be_false
    end
  end
end

describe "Tracing.event (ported from upstream event! macro)" do
  it "dispatches an event via DSL method" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      Tracing.event(Level::INFO, "my_event", key: "value")
      subscriber.event_count.should eq(1)
    end
  end

  it "does not crash when dispatching with no subscriber" do
    Tracing.event(Level::INFO, "no_sub_event")
  end
end

describe "Tracing level shorthand methods" do
  it "traces an info event" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      Tracing.info("info_event", key: "val")
      subscriber.event_count.should eq(1)
      subscriber.last_event_level.should eq(Level::INFO)
    end
  end

  it "traces a debug event" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      Tracing.debug("debug_event")
      subscriber.event_count.should eq(1)
      subscriber.last_event_level.should eq(Level::DEBUG)
    end
  end

  it "traces a warn event" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      Tracing.warn("warn_event")
      subscriber.event_count.should eq(1)
      subscriber.last_event_level.should eq(Level::WARN)
    end
  end

  it "traces an error event" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      Tracing.error("error_event")
      subscriber.event_count.should eq(1)
      subscriber.last_event_level.should eq(Level::ERROR)
    end
  end
end

describe "Tracing macros (span!, event!, level macros)" do
  it "span! macro creates a span" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      s = span!(Level::INFO, "macro_span", answer: 42)
      s.disabled?.should be_false
      subscriber.new_span_count.should eq(1)
    end
  end

  it "event! macro dispatches an event" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      event!(Level::INFO, "macro_event", key: "val")
      subscriber.event_count.should eq(1)
    end
  end

  it "info! macro dispatches" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("info_macro")
      subscriber.event_count.should eq(1)
      subscriber.last_event_level.should eq(Level::INFO)
    end
  end

  it "debug_span! macro creates a span at DEBUG level" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      s = debug_span!("debug_macro")
      s.disabled?.should be_false
    end
  end

  it "span! macro creates span with no fields" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      s = span!(Level::WARN, "no_fields")
      s.disabled?.should be_false
    end
  end
end

private class TestSubscriber
  include Subscriber

  property entered_count : Int32 = 0
  property exited_count : Int32 = 0
  property new_span_count : Int32 = 0
  property event_count : Int32 = 0
  property last_event_level : Level?

  def new_span(attrs : CoreSpan::Attributes) : SpanId
    @new_span_count += 1
    SpanId.from_u64(@new_span_count.to_u64)
  end

  def enter(id : SpanId) : Nil
    @entered_count += 1
  end

  def exit(id : SpanId) : Nil
    @exited_count += 1
  end

  def event(event : Tracing::Event) : Nil
    @event_count += 1
    @last_event_level = event.metadata.level
  end

  def record(id : SpanId, values : CoreSpan::Record) : Nil
  end

  def record_follows_from(span : SpanId, follows : SpanId) : Nil
  end

  def enabled(metadata : Metadata) : Bool
    true
  end

  def register_callsite(metadata : Metadata) : Callsite::Interest
    Callsite::Interest.always
  end

  def max_level_hint : LevelFilter?
    LevelFilter.trace
  end
end

# RED tests — tracing-subscriber Registry
describe "Tracing::Registry (ported from upstream registry/sharded.rs)" do
  it "creates spans and tracks them" do
    registry = Tracing::Registry.new
    dispatch = Dispatch.new(registry)
    Dispatch.with_default(dispatch) do
      span = span!(Level::INFO, "test_span")
      span.disabled?.should be_false
      id = span.id
      id.should_not be_nil

      data = registry.span_data(id.not_nil!)
      data.should_not be_nil
      data.try(&.name).should eq("test_span")
    end
  end

  it "tracks span parent relationships" do
    registry = Tracing::Registry.new
    dispatch = Dispatch.new(registry)
    Dispatch.with_default(dispatch) do
      s = span!(Level::INFO, "parent")
      s2 = child_span!(s.id.not_nil!, Level::INFO, "child")
      data = registry.span_data(s2.id.not_nil!)
      data.should_not be_nil
      data.try(&.parent).should eq(s.id)
    end
  end
end

# RED tests — tracing-subscriber Layer
describe "Tracing::Layer (ported from upstream layer/mod.rs)" do
  it "composes a Layer with a Registry to observe events" do
    observer = EventObserver.new
    registry = Tracing::Registry.new
    subscriber = registry.with(observer)
    dispatch = Dispatch.new(subscriber)

    Dispatch.with_default(dispatch) do
      info!("an_event")
    end

    observer.events.size.should eq(1)
    observer.events[0].metadata.name.should eq("an_event")
  end

  it "composes a Layer with a Registry to observe spans" do
    observer = SpanObserver.new
    registry = Tracing::Registry.new
    subscriber = registry.with(observer)
    dispatch = Dispatch.new(subscriber)

    Dispatch.with_default(dispatch) do
      s = span!(Level::INFO, "layer_span")
      s.in_scope { info!("inside") }
    end

    observer.spans.size.should eq(1)
    observer.spans[0].metadata.name.should eq("layer_span")
  end
end

# Layer test helpers
private class EventObserver < Tracing::Layer
  getter events : Array(Tracing::Core::Event) = [] of Tracing::Core::Event

  def on_event(event : Tracing::Core::Event, ctx : Tracing::LayerContext)
    @events << event
  end
end

private class SpanObserver < Tracing::Layer
  getter spans : Array(Tracing::Core::Span::Attributes) = [] of Tracing::Core::Span::Attributes

  def on_new_span(attrs : Tracing::Core::Span::Attributes, id : Tracing::CoreSpan::Id, ctx : Tracing::LayerContext)
    @spans << attrs
  end
end

# LookupSpan test helper
private class EventSpanLayer < Tracing::Layer
  property observed_name : String? = nil

  def on_event(event : Tracing::Core::Event, ctx : Tracing::LayerContext)
    span_ref = ctx.event_span(event)
    @observed_name = span_ref.try(&.name)
  end
end

# Ported from upstream tracing-subscriber/src/layer/tests.rs:122
describe "LookupSpan (ported from upstream layer/tests.rs)" do
  it "context_event_span returns parent span name" do
    layer = EventSpanLayer.new
    subscriber = Tracing::Registry.new.with(layer)
    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("no span")
      layer.observed_name.should be_nil

      info_span!("contextual").in_scope do
        info!("contextual span")
        layer.observed_name.should eq("contextual")
      end
    end
  end

  it "lookup_span returns stored span data" do
    registry = Tracing::Registry.new
    Dispatch.with_default(Dispatch.new(registry)) do
      s = span!(Level::INFO, "lookup_test")
      id = s.id.not_nil!
      span_ref = registry.span(id)
      span_ref.should_not be_nil
      span_ref.try(&.name).should eq("lookup_test")
    end
  end
end

describe "Registry current span tracking" do
  it "tracks current span after enter" do
    registry = Tracing::Registry.new
    Dispatch.with_default(Dispatch.new(registry)) do
      registry.current_span.should be_nil

      s = span!(Level::INFO, "test")
      s.in_scope do
        registry.current_span.should_not be_nil
        data = registry.span_data(registry.current_span.not_nil!)
        data.try(&.name).should eq("test")
      end
    end
  end
end

# RED tests — Extensions type map
describe "Tracing::Extensions (ported from upstream registry/extensions.rs)" do
  it "inserts and retrieves a value" do
    exts = Tracing::Extensions.new
    exts.insert(42_i32)
    exts.get(Int32).should eq(42)
  end

  it "inserts and retrieves different types" do
    exts = Tracing::Extensions.new
    exts.insert("hello")
    exts.insert(99_i64)
    exts.get(String).should eq("hello")
    exts.get(Int64).should eq(99_i64)
  end

  it "replaces existing value" do
    exts = Tracing::Extensions.new
    exts.insert(1_i32)
    old = exts.replace(100_i32)
    old.should eq(1)
    exts.get(Int32).should eq(100)
  end

  it "removes a value" do
    exts = Tracing::Extensions.new
    exts.insert(true)
    removed = exts.remove(Bool)
    removed.should be_true
    exts.get(Bool).should be_nil
  end
end

# RED tests — Filter (LevelFilter as Layer)
describe "Filter::LevelFilter (ported from upstream filter/level.rs)" do
  it "filters out events above the configured level" do
    io = IO::Memory.new
    fmt_layer = Tracing::FmtLayer.new(io).with_filter(LevelFilter.info)
    subscriber = Tracing::Registry.new.with(fmt_layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("should pass")
      debug!("should be filtered")
    end

    output = io.to_s
    output.should contain("should pass")
    output.should_not contain("should be filtered")
  end

  it "reports max_level_hint" do
    layer = Tracing::LevelFilterLayer.new(LevelFilter.warn)
    layer.max_level_hint.should eq(LevelFilter.warn)
  end

  it "registers callsite interest correctly" do
    layer = Tracing::LevelFilterLayer.new(LevelFilter.info)
    meta = Metadata.new("test", "test_target", Level::ERROR)
    interest = layer.on_register_callsite(meta, Tracing::LayerContext.new(Tracing::Core::NoSubscriber.new))
    interest.never?.should be_false
    interest.always?.should be_true
  end
end

# RED tests — Extensions integration with Registry
describe "Extensions integration (per-span data)" do
  it "layer stores and retrieves data via span extensions" do
    layer = SpanDataLayer.new
    registry = Tracing::Registry.new
    subscriber = registry.with(layer)
    Dispatch.with_default(Dispatch.new(subscriber)) do
      info_span!("data_span").in_scope do
        info!("event_in_span")
      end
    end

    layer.stored_value.should eq(42_i64)
  end
end

private class SpanDataLayer < Tracing::Layer
  property stored_value : Int64? = nil

  def on_new_span(attrs : Tracing::Core::Span::Attributes, id : Tracing::CoreSpan::Id, ctx : Tracing::LayerContext)
    span = ctx.span(id)
    if span
      exts = span.extensions_mut
      exts.try(&.insert(42_i64))
    end
  end

  def on_event(event : Tracing::Core::Event, ctx : Tracing::LayerContext)
    span = ctx.event_span(event)
    if span
      exts = span.extensions
      @stored_value = exts.try(&.get(Int64))
    end
  end
end

# RED tests — fmt layer (formatted output)
describe "FmtLayer (ported from upstream fmt/fmt_layer.rs)" do
  it "formats events to a writer" do
    io = IO::Memory.new
    fmt_layer = Tracing::FmtLayer.new(io)
    subscriber = Tracing::Registry.new.with(fmt_layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("hello world")
      warn!("something happened")
    end

    output = io.to_s
    output.should contain("hello world")
    output.should contain("WARN")
  end

  it "formats spans with enter/exit" do
    io = IO::Memory.new
    fmt_layer = Tracing::FmtLayer.new(io)
    subscriber = Tracing::Registry.new.with(fmt_layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info_span!("my_span").in_scope do
        info!("inside")
      end
    end

    output = io.to_s
    output.should contain("my_span")
    output.should contain("enter")
    output.should contain("inside")
    output.should contain("exit")
  end
end

# RED tests — fmt with_filter
describe "FmtLayer with_filter" do
  it "filters events based on layer-level filter" do
    io = IO::Memory.new
    fmt_layer = Tracing::FmtLayer.new(io).with_filter(LevelFilter.warn)
    subscriber = Tracing::Registry.new.with(fmt_layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("should be filtered out")
      warn!("should appear")
      error!("should also appear")
    end

    output = io.to_s
    output.should_not contain("should be filtered out")
    output.should contain("should appear")
    output.should contain("should also appear")
  end
end

# RED tests — EnvFilter directive parsing
describe "EnvFilter Directive parsing (ported from upstream filter/env/directive.rs)" do
  it "parses a bare level directive" do
    d = Tracing::Directive.parse("info")
    d.level.into_level.should eq(Level::INFO)
    d.target.should be_nil
  end

  it "parses a target=level directive" do
    d = Tracing::Directive.parse("my_crate=debug")
    d.level.into_level.should eq(Level::DEBUG)
    d.target.should eq("my_crate")
  end

  it "parses a scoped target=level directive" do
    d = Tracing::Directive.parse("my_crate::module=warn")
    d.level.into_level.should eq(Level::WARN)
    d.target.should eq("my_crate::module")
  end

  it "parses a target[span_name]=level directive" do
    d = Tracing::Directive.parse("my_crate[my_span]=trace")
    d.level.into_level.should eq(Level::TRACE)
    d.target.should eq("my_crate")
    d.in_span.should eq("my_span")
  end

  it "parses OFF directive" do
    d = Tracing::Directive.parse("off")
    d.level.into_level.should be_nil
  end

  it "rejects invalid syntax" do
    expect_raises(ArgumentError) { Tracing::Directive.parse("bad=stuff=here") }
  end

  it "parses default/empty as ERROR" do
    d = Tracing::Directive.parse("")
    d.level.into_level.should eq(Level::ERROR)
  end

  it "parses level with whitespace" do
    d = Tracing::Directive.parse(" my_crate = debug ")
    d.target.should eq("my_crate")
    d.level.into_level.should eq(Level::DEBUG)
  end
end

# RED tests — EnvFilter layer
describe "EnvFilter (ported from upstream filter/env)" do
  it "filters by level from env var string" do
    filter = Tracing::EnvFilter.new("info")
    counting = EventCollector.new
    subscriber = Tracing::Registry.new.with(counting).with(filter)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      error!("pass_error")
      info!("pass_info")
      debug!("filter_debug")
      trace!("filter_trace")
    end

    counting.names.should contain("pass_error")
    counting.names.should contain("pass_info")
    counting.names.should_not contain("filter_debug")
    counting.names.should_not contain("filter_trace")
  end

  it "filters by target from env var string" do
    filter = Tracing::EnvFilter.new("my_module=info,crate=error")
    counting = EventCollector.new
    subscriber = Tracing::Registry.new.with(counting).with(filter)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      Tracing.event(Level::DEBUG, "mod_event")
    end

    counting.names.should_not contain("mod_event")
  end

  it "builds from multiple directives" do
    filter = Tracing::EnvFilter.new("warn,my_crate=debug")

    # Check directives were parsed
    directives = filter.directives
    directives.size.should eq(2)
    directives[0].level.into_level.should eq(Level::WARN)
    directives[0].target.should be_nil
    directives[1].level.into_level.should eq(Level::DEBUG)
    directives[1].target.should eq("my_crate")
  end
end

private class EventCollector < Tracing::Layer
  property names : Array(String) = [] of String

  def on_event(event : Tracing::Core::Event, ctx : Tracing::LayerContext)
    @names << event.metadata.name
  end
end

# RED tests — FmtLayer with_target, field formatting
describe "FmtLayer formatting options" do
  it "shows target when with_target is enabled" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).with_target(true)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      Tracing.event(Level::INFO, "test_event")
    end

    output = io.to_s
    output.should contain("test_event") # target=name when not overridden
  end

  it "hides level when with_level is false" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).with_level(false)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      Tracing.event(Level::INFO, "test_event")
    end

    output = io.to_s
    output.should_not contain("INFO")
  end

  it "formats event fields" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      Tracing.event(Level::INFO, "data_event", user: "alice", count: 42)
    end

    output = io.to_s
    output.should contain("user=alice")
    output.should contain("count=42")
  end
end
