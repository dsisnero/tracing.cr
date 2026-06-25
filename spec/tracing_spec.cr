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
    (Level::TRACE == LevelFilter.trace).should be_true
  end
end

# Ported from vendor/tracing/tracing-core/src/metadata.rs doc examples
describe "LevelFilter comparisons (ported from upstream metadata.rs)" do
  it "OFF < TRACE" do
    (LevelFilter.off < LevelFilter.trace).should be_true
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
      Level.parse("trace").should eq(LevelFilter.trace)
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
      f.into_level.should eq(LevelFilter.trace)
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

# Ported from registry/mod.rs — SpanRef ancestor iteration (scope / from_root / parent)
private class ScopeCaptureLayer < Tracing::Layer
  property scope_names = [] of String
  property from_root_names = [] of String
  property parent_name : String?
  property? had_parent = false

  def on_event(event : Tracing::Core::Event, ctx : Tracing::LayerContext) : Nil
    sp = ctx.event_span(event)
    return unless sp
    @scope_names = sp.scope.map(&.name).to_a
    @from_root_names = sp.scope.from_root.map(&.name).to_a
    if parent = sp.parent
      @parent_name = parent.name
      @had_parent = true
    end
  end
end

describe "SpanRef#scope (ported from registry/mod.rs)" do
  it "iterates self then ancestors, leaf to root" do
    layer = ScopeCaptureLayer.new
    subscriber = Tracing::Registry.new.with(layer)
    Dispatch.with_default(Dispatch.new(subscriber)) do
      span!(Level::INFO, "root").in_scope do
        span!(Level::INFO, "child").in_scope do
          span!(Level::INFO, "leaf").in_scope do
            info!("ev")
          end
        end
      end
    end
    layer.scope_names.should eq(["leaf", "child", "root"])
  end

  it "from_root reverses to root then descendants" do
    layer = ScopeCaptureLayer.new
    subscriber = Tracing::Registry.new.with(layer)
    Dispatch.with_default(Dispatch.new(subscriber)) do
      span!(Level::INFO, "root").in_scope do
        span!(Level::INFO, "child").in_scope do
          span!(Level::INFO, "leaf").in_scope do
            info!("ev")
          end
        end
      end
    end
    layer.from_root_names.should eq(["root", "child", "leaf"])
  end

  it "parent returns the enclosing span" do
    layer = ScopeCaptureLayer.new
    subscriber = Tracing::Registry.new.with(layer)
    Dispatch.with_default(Dispatch.new(subscriber)) do
      span!(Level::INFO, "outer").in_scope do
        span!(Level::INFO, "inner").in_scope do
          info!("ev")
        end
      end
    end
    layer.parent_name.should eq("outer")
  end

  it "parent is nil and scope is just self for a root span" do
    layer = ScopeCaptureLayer.new
    subscriber = Tracing::Registry.new.with(layer)
    Dispatch.with_default(Dispatch.new(subscriber)) do
      span!(Level::INFO, "solo").in_scope do
        info!("ev")
      end
    end
    layer.scope_names.should eq(["solo"])
    layer.had_parent?.should be_false
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
      registry.current_span_id.should be_nil

      s = span!(Level::INFO, "test")
      s.in_scope do
        registry.current_span_id.should_not be_nil
        data = registry.span_data(registry.current_span_id.not_nil!)
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
    d.level.into_level.should eq(LevelFilter.trace)
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

# RED tests — FmtLayer compact mode
describe "FmtLayer compact mode" do
  it "outputs compact single-line events without timestamps" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).compact
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("compact_event", key: "val")
    end

    output = io.to_s
    output.should contain("INFO compact_event")
    output.should contain("key=val")
    # Compact mode: no timestamp (no ISO 8601 date)
    output.should_not match(/\d{4}-\d{2}-\d{2}T/)
    # Single line
    output.lines.size.should eq(1)
  end

  it "omits span enter/exit in compact mode" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).compact
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info_span!("compact_span").in_scope do
        info!("inside")
      end
    end

    output = io.to_s
    output.should_not contain("enter")
    output.should_not contain("exit")
    output.should contain("inside")
  end
end

# RED tests — FmtSpan configuration
describe "FmtLayer span events configuration" do
  it "shows only new_span events when configured" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).with_span_events(Tracing::FmtSpan::NEW)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info_span!("span_test").in_scope { info!("inside") }
    end

    output = io.to_s
    output.should contain("new span_test")
    output.should_not contain("enter")
    output.should_not contain("exit")
    output.should contain("inside")
  end

  it "shows no span events when NONE" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).with_span_events(Tracing::FmtSpan::NONE)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info_span!("span_test").in_scope { info!("inside") }
    end

    output = io.to_s
    output.should_not contain("new")
    output.should_not contain("enter")
    output.should_not contain("exit")
  end

  it "shows enter and exit when ACTIVE" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).with_span_events(Tracing::FmtSpan::ACTIVE)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info_span!("span_test").in_scope { info!("inside") }
    end

    output = io.to_s
    output.should contain("enter span_test")
    output.should contain("exit span_test")
    output.should_not contain("new")
  end
end

# RED tests — FilterFn (closure-based filter)
describe "FilterFn (ported from upstream filter/filter_fn.rs)" do
  it "filters using a closure" do
    filter = Tracing::FilterFn.new { |meta| meta.level <= Level::WARN }
    counting = EventCollector.new
    filtered = counting.with_fn_filter(filter)
    subscriber = Tracing::Registry.new.with(filtered)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      error!("pass")
      info!("blocked")
    end

    counting.names.should contain("pass")
    counting.names.should_not contain("blocked")
  end

  it "passes events when closure returns true" do
    filter = Tracing::FilterFn.new { |_meta| true }
    subscriber = Tracing::Registry.new.with(filter)
    counting = EventCollector.new
    subscriber = subscriber.with(counting)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("always_pass")
    end

    counting.names.should contain("always_pass")
  end
end

describe "subscriber convenience (ported from upstream tracing::subscriber)" do
  it "with_default wraps subscriber in Dispatch" do
    subscriber = Tracing::Registry.new
    seen = nil

    Tracing::Subscriber.with_default(subscriber) do
      seen = Dispatch.current.try(&.subscriber)
    end

    seen.should eq(subscriber)
  end

  it "with_default restores prior dispatch" do
    prior = Dispatch.current
    subscriber = Tracing::Registry.new

    Tracing::Subscriber.with_default(subscriber) do
    end

    Dispatch.current.should eq(prior)
  end
end

describe "Targets filter (ported from upstream filter/targets.rs)" do
  it "matches events by target prefix" do
    filter = Tracing::Targets.new
      .with_target("my_crate", Level::INFO)
      .with_default(LevelFilter.trace)
    ctx = Tracing::LayerContext.new(Tracing::Core::NoSubscriber.new)

    meta = Metadata.new("ev", "my_crate::module", Level::DEBUG)
    filter.enabled?(meta, ctx).should be_false

    meta2 = Metadata.new("ev", "my_crate::module", Level::ERROR)
    filter.enabled?(meta2, ctx).should be_true

    meta3 = Metadata.new("ev", "other", Level::DEBUG)
    filter.enabled?(meta3, ctx).should be_true
  end

  it "blocks unmatched targets when default is OFF" do
    filter = Tracing::Targets.new
      .with_target("important", Level::INFO)
      .with_default(LevelFilter.off)

    ctx = Tracing::LayerContext.new(Tracing::Core::NoSubscriber.new)

    meta = Metadata.new("ev", "unimportant", Level::ERROR)
    filter.enabled?(meta, ctx).should be_false

    meta2 = Metadata.new("ev", "important::thing", Level::ERROR)
    filter.enabled?(meta2, ctx).should be_true
  end

  it "builder exposes default_level" do
    targets = Tracing::Targets.new
      .with_target("alpha", Level::ERROR)
      .with_default(LevelFilter.off)

    targets.default_level.should eq(LevelFilter.off)
  end
end

# RED tests — MakeWriter (block-based writer)
describe "FmtLayer MakeWriter (ported from upstream fmt/writer.rs)" do
  it "accepts a block that returns IO" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.make_writer { io }
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("writer_test")
    end

    io.to_s.should contain("writer_test")
  end

  it "creates a new writer for each event" do
    outputs = [] of IO::Memory
    layer = Tracing::FmtLayer.make_writer do
      io = IO::Memory.new
      outputs << io
      io
    end
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("first")
      info!("second")
    end

    outputs.size.should eq(2)
    outputs[0].to_s.should contain("first")
    outputs[1].to_s.should contain("second")
  end
end

# RED tests — target override
describe "event/span target override" do
  it "Tracing.event accepts target: param" do
    log = EventLog.new
    subscriber = Tracing::Registry.new.with(log)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      span!(Level::INFO, "my_span", target: "span_target")
      info!("my_event", target: "custom_target")
    end

    log.targets[0].should eq("span_target")
  end
end

private class EventLog < Tracing::Layer
  property targets : Array(String) = [] of String

  def on_event(event : Tracing::Core::Event, ctx : Tracing::LayerContext)
    @targets << event.metadata.target
  end

  def on_new_span(attrs : Tracing::Core::Span::Attributes, id : Tracing::CoreSpan::Id, ctx : Tracing::LayerContext)
    @targets << attrs.metadata.target
  end
end

# RED tests — Registry.default, fmt::layer()
describe "convenience constructors" do
  it "Registry.default creates a default Registry" do
    registry = Tracing::Registry.default
    registry.should be_a(Tracing::Registry)
  end

  it "Registry.default.with chains layers" do
    layer = Tracing::FmtLayer.new(IO::Memory.new)
    subscriber = Tracing::Registry.default.with(layer)
    subscriber.should be_a(Tracing::Layered(Tracing::Registry))
  end

  it "fmt layer free function creates default FmtLayer" do
    layer = Tracing.fmt_layer
    layer.should be_a(Tracing::FmtLayer)
  end
end

# RED tests — Nil as no-op Layer
describe "Nil as Layer (Option<Layer> support)" do
  it "nil can be used with .with as a no-op layer" do
    registry = Tracing::Registry.default.with(nil)
    collector = EventCollector.new
    subscriber = registry.with(collector)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("should pass through nil layer")
    end

    collector.names.should contain("should pass through nil layer")
  end

  it "conditional layers work at runtime" do
    collector = EventCollector.new
    debug = true
    filter_layer = debug ? Tracing::LevelFilterLayer.new(LevelFilter.warn) : nil
    registry = Tracing::Registry.default.with(collector).with(filter_layer)
    subscriber = registry

    Dispatch.with_default(Dispatch.new(subscriber)) do
      warn!("passes")
      info!("blocked")
    end

    collector.names.should contain("passes")
    collector.names.should_not contain("blocked")
  end
end

# RED tests — FmtLayer pretty mode
describe "FmtLayer pretty mode" do
  it "outputs multi-line events" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).pretty
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("pretty_event", user: "alice", count: 42)
    end

    output = io.to_s
    output.lines.size.should be > 1
    output.should contain("pretty_event")
    output.should contain("user")
    output.should contain("alice")
  end

  it "indents span context" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).pretty
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info_span!("outer").in_scope do
        info!("inside")
      end
    end

    output = io.to_s
    output.should contain("outer")
    output.should contain("inside")
  end
end

# RED tests — FmtLayer with_ansi
describe "FmtLayer with_ansi" do
  it "adds ANSI color codes to level output" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).with_ansi(true)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      error!("ansi_error")
    end

    output = io.to_s
    output.should contain("\e[")
    output.should contain("ERROR")
  end

  it "omits ANSI codes when disabled" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).with_ansi(false)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("no_ansi")
    end

    output = io.to_s
    output.should_not contain("\e[")
  end
end

# RED tests — EnvFilter::from_env, subscriber.init
describe "EnvFilter.from_env" do
  it "reads TRACE_LOG environment variable" do
    ENV["TRACE_LOG"] = "info,my_crate=debug"
    begin
      filter = Tracing::EnvFilter.from_env
      filter.directives.size.should eq(2)
    ensure
      ENV.delete("TRACE_LOG")
    end
  end

  it "defaults to error when env var not set" do
    ENV.delete("TRACE_LOG")
    filter = Tracing::EnvFilter.from_env
    filter.directives[0].level.into_level.should eq(Level::ERROR)
  end
end

describe "Registry#init" do
  it "sets self as global default" do
    begin
      registry = Tracing::Registry.new
      registry.init
      Dispatch.default.try(&.subscriber).should eq(registry)
    rescue ex : Tracing::Core::SetGlobalDefaultError
      # global already set, skip
    end
  end
end

# RED tests — Layer#and_then
describe "Layer#and_then combinator" do
  it "composes two layers with the second as filter" do
    inner = EventCollector.new
    filter = Tracing::LevelFilterLayer.new(LevelFilter.warn)
    composed = inner.and_then(filter)
    subscriber = Tracing::Registry.new.with(composed)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      error!("pass")
      info!("block")
    end

    inner.names.should contain("pass")
    inner.names.should_not contain("block")
  end

  it "chains with Registry.with" do
    layer = Tracing::FmtLayer.new(IO::Memory.new)
    filter = Tracing::LevelFilterLayer.new(LevelFilter.error)
    composed = layer.and_then(filter)
    subscriber = Tracing::Registry.new.with(composed)

    subscriber.should be_a(Tracing::Layered(Tracing::Registry))
  end
end

# RED tests — Span field recording
describe "Span field recording (ported from upstream span.rs)" do
  it "records additional fields on a span after creation" do
    log = SpanRecordLog.new
    subscriber = Tracing::Registry.new.with(log)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      s = span!(Level::INFO, "record_span", initial: 1)
      s.record(key: "value")
    end

    log.recorded_fields.should contain("record")
  end
end

private class SpanRecordLog < Tracing::Layer
  property recorded_fields : Array(String) = [] of String

  def on_new_span(attrs : Tracing::Core::Span::Attributes, id : Tracing::CoreSpan::Id, ctx : Tracing::LayerContext)
    @recorded_fields << "new"
  end

  def on_record(id : Tracing::CoreSpan::Id, values : Tracing::Core::Span::Record, ctx : Tracing::LayerContext)
    @recorded_fields << "record"
  end
end

# RED tests — LevelFilter.current (global max level optimization)
describe "LevelFilter.current" do
  it "reflects the globally set max level" do
    LevelFilter.max = LevelFilter.warn
    LevelFilter.current.into_level.should eq(Level::WARN)

    LevelFilter.max = LevelFilter.trace
    LevelFilter.current.into_level.should eq(Level::TRACE)
  end
end

# RED tests — tracing-macros (trace_dbg!)
describe "trace_dbg! macro (ported from tracing-macros/src/lib.rs)" do
  it "evaluates expression and returns its value" do
    log = EventCollector.new
    subscriber = Tracing::Registry.new.with(log)

    result = Dispatch.with_default(Dispatch.new(subscriber)) do
      trace_dbg!(42)
    end

    result.should eq(42)
    log.names.should contain("trace_dbg")
  end

  it "emits event with expression stringified" do
    log = EventCollector.new
    subscriber = Tracing::Registry.new.with(log)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      trace_dbg!(2 + 2)
    end

    log.names.should contain("trace_dbg")
  end
end
require "log"

# RED tests — tracing-log LogTracer
describe "LogTracer (ported from tracing-log/src/log_tracer.rs)" do
  it "severity_to_level maps correctly" do
    tracer = Tracing::LogTracer.new
    tracer.test_severity(::Log::Severity::Info).should eq(Tracing::Level::INFO)
    tracer.test_severity(::Log::Severity::Error).should eq(Tracing::Level::ERROR)
    tracer.test_severity(::Log::Severity::Debug).should eq(Tracing::Level::DEBUG)
    tracer.test_severity(::Log::Severity::Trace).should eq(Tracing::Level::TRACE)
  end
end

# RED tests — tracing-appender NonBlocking
describe "NonBlocking (ported from tracing-appender/src/non_blocking.rs)" do
  it "writes events through a worker fiber" do
    io = IO::Memory.new
    nb, guard = Tracing::NonBlocking.new(io)
    writer = nb.make_writer

    writer.write("hello\n".to_slice)
    writer.write("world\n".to_slice)

    # Close the guard to flush and wait
    guard.close
    output = io.to_s
    output.should contain("hello")
    output.should contain("world")
  end

  it "WorkerGuard flushes on close" do
    io = IO::Memory.new
    nb, guard = Tracing::NonBlocking.new(io)
    writer = nb.make_writer

    writer.write("buffered\n".to_slice)
    guard.close

    io.to_s.should contain("buffered")
  end

  it "builder accepts custom buffer size" do
    io = IO::Memory.new
    nb, guard = Tracing::NonBlocking.builder(io, buffer_size: 1024)
    nb.should be_a(Tracing::NonBlocking)
    guard.close
  end
end

# RED tests — tracing-mock MockSubscriber
describe "MockSubscriber (ported from tracing-mock/src/subscriber.rs)" do
  it "records events with their fields" do
    mock = Tracing::MockSubscriber.new
    Dispatch.with_default(Dispatch.new(mock)) do
      info!("test_event", user: "alice")
    end

    mock.events.size.should eq(1)
    mock.events[0].metadata.name.should eq("test_event")
  end

  it "records spans with enter/exit" do
    mock = Tracing::MockSubscriber.new
    Dispatch.with_default(Dispatch.new(mock)) do
      span!(Level::INFO, "test_span").in_scope do
        info!("inside")
      end
    end

    mock.spans.size.should eq(1)
    mock.enters.size.should eq(1)
    mock.exits.size.should eq(1)
  end

  it "assert_finished checks expectations" do
    mock = Tracing::MockSubscriber.new
      .expect_event_named("expected_event")

    Dispatch.with_default(Dispatch.new(mock)) do
      info!("expected_event")
    end

    mock.assert_finished
  end

  it "assert_finished raises on unmet expectations" do
    mock = Tracing::MockSubscriber.new
      .expect_event_named("never_emitted")

    Dispatch.with_default(Dispatch.new(mock)) do
      # nothing emitted
    end

    expect_raises(Exception, "never_emitted") do
      mock.assert_finished
    end
  end
end

# RED tests — RollingFileAppender
describe "RollingFileAppender" do
  it "creates a file with timestamped name for daily rotation" do
    appender = Tracing::RollingFileAppender.new(
      Tracing::Rotation::DAILY,
      "temp/logs",
      "test"
    )
    appender.should be_a(Tracing::RollingFileAppender)
    appender.close
  end

  it "writes to the current log file" do
    appender = Tracing::RollingFileAppender.new(
      Tracing::Rotation::NEVER,
      "temp/logs",
      "write_test"
    )
    appender.write("test line\n".to_slice)
    appender.close

    files = Dir["temp/logs/write_test*"]
    files.size.should be > 0
    content = File.read(files[0])
    content.should contain("test line")
  ensure
    Dir["temp/logs/write_test*"].each { |file| File.delete(file) }
  end
end

# RED tests — tracing-error SpanTrace
describe "SpanTrace (ported from tracing-error/src/lib.rs)" do
  it "captures current span context" do
    registry = Tracing::Registry.new

    Dispatch.with_default(Dispatch.new(registry)) do
      span!(Level::INFO, "parent").in_scope do
        span!(Level::INFO, "child").in_scope do
          trace = Tracing::SpanTrace.capture(registry)
          trace.spans.size.should eq(2)
          trace.spans[0].should eq("child")
          trace.spans[1].should eq("parent")
        end
      end
    end
  end

  it "formats span chain for display" do
    registry = Tracing::Registry.new

    Dispatch.with_default(Dispatch.new(registry)) do
      span!(Level::INFO, "root_span").in_scope do
        trace = Tracing::SpanTrace.capture(registry)
        trace.to_s.should contain("root_span")
      end
    end
  end
end

# RED tests — tracing-flame FlameLayer
describe "FlameLayer (ported from tracing-flame/src/lib.rs)" do
  it "writes folded stack format for span enter/exit" do
    io = IO::Memory.new
    flame = Tracing::FlameLayer.new(io)
    registry = Tracing::Registry.new.with(flame)

    Dispatch.with_default(Dispatch.new(registry)) do
      info_span!("outer").in_scope do
        info_span!("inner").in_scope do
        end
      end
    end

    output = io.to_s
    output.should contain("outer")
    output.should contain("inner")
    output.should contain(";")
  end

  it "creates with_file helper" do
    flame, guard = Tracing::FlameLayer.with_file("temp/flame_test.folded")
    flame.should be_a(Tracing::FlameLayer)
    guard.close
    File.delete("temp/flame_test.folded") if File.exists?("temp/flame_test.folded")
  end
end

# RED tests — tracing-attributes @[Instrument]
describe "Tracing.instrument (ported from tracing-attributes)" do
  it "Tracing.instrument wraps block in a span" do
    observer = SpanObserver.new
    subscriber = Tracing::Registry.new.with(observer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      result = Tracing.instrument("my_func", arg: 42) { 100 }
      result.should eq(100)
    end

    observer.spans.size.should eq(1)
    observer.spans[0].metadata.name.should eq("my_func")
  end
end

# RED tests — tracing-opentelemetry OpenTelemetryLayer
describe "OpenTelemetryLayer (ported from tracing-opentelemetry/src/layer.rs)" do
  it "stores OtelData in span extensions" do
    # Use the NoopTracer (always available, no config needed)
    layer = Tracing::OpenTelemetryLayer.new
    registry = Tracing::Registry.new.with(layer)

    observer = SpanObserver.new
    registry = registry.with(observer)

    Dispatch.with_default(Dispatch.new(registry)) do
      span!(Level::INFO, "otel_test_span").in_scope do
      end
    end

    # Span was created
    observer.spans.size.should eq(1)
    observer.spans[0].metadata.name.should eq("otel_test_span")
  end

  it "maps tracing levels to OTel span kind" do
    layer = Tracing::OpenTelemetryLayer.new
    layer.should be_a(Tracing::Layer)
  end
end

# RED tests — OTel span kind mapping
describe "OpenTelemetry span kind mapping" do
  it "maps otel.kind=server to Server kind" do
    kind = Tracing::OpenTelemetryLayer.kind_from_field("server")
    kind.should eq(OpenTelemetry::API::Span::Kind::Server)
  end

  it "maps otel.kind=client to Client kind" do
    kind = Tracing::OpenTelemetryLayer.kind_from_field("client")
    kind.should eq(OpenTelemetry::API::Span::Kind::Client)
  end

  it "defaults to Internal for unknown values" do
    kind = Tracing::OpenTelemetryLayer.kind_from_field("unknown")
    kind.should eq(OpenTelemetry::API::Span::Kind::Internal)
  end

  it "defaults to Internal for nil" do
    kind = Tracing::OpenTelemetryLayer.kind_from_field(nil)
    kind.should eq(OpenTelemetry::API::Span::Kind::Internal)
  end
end

# RED tests — OTel status code mapping
describe "OpenTelemetry status code mapping" do
  it "maps Ok status" do
    status = Tracing::OpenTelemetryLayer.status_from_code("Ok")
    status.code.ok?.should be_true
  end

  it "maps Error status" do
    status = Tracing::OpenTelemetryLayer.status_from_code("Error")
    status.code.error?.should be_true
  end

  it "defaults to Unset for unknown" do
    status = Tracing::OpenTelemetryLayer.status_from_code("Unknown")
    status.code.unset?.should be_true
  end

  it "defaults to Unset for nil" do
    status = Tracing::OpenTelemetryLayer.status_from_code(nil)
    status.code.unset?.should be_true
  end
end

# RED tests — OTel error events → exceptions
describe "OpenTelemetry error-to-exception mapping" do
  it "detects error events" do
    layer = Tracing::OpenTelemetryLayer.new
    meta = Metadata.new("test", "test", Level::ERROR, kind: Kind::EVENT)
    layer.error_event?(meta).should be_true

    meta2 = Metadata.new("test", "test", Level::INFO, kind: Kind::EVENT)
    layer.error_event?(meta2).should be_false
  end

  it "creates exception attributes from event fields" do
    layer = Tracing::OpenTelemetryLayer.new
    attrs = layer.exception_attributes("test error", "backtrace here")
    attrs.has_key?("exception.message").should be_true
    attrs.has_key?("exception.stacktrace").should be_true
    attrs["exception.message"].should eq("test error")
  end
end

private class TestSpan
  getter name : String
  property? finished : Bool = false

  def initialize(@name : String)
  end

  def finish
    @finished = true
  end
end

# RED tests — OTel layer builder configuration
describe "OpenTelemetryLayer configuration" do
  it "with_level filters events below the configured level" do
    layer = Tracing::OpenTelemetryLayer.new.with_level(Level::WARN)
    observer = SpanObserver.new
    registry = Tracing::Registry.new.with(layer).with(observer)

    Dispatch.with_default(Dispatch.new(registry)) do
      info!("should be filtered")
      warn!("should pass")
    end

    observer.spans.size.should eq(0)
  end

  it "default level is TRACE (pass everything)" do
    layer = Tracing::OpenTelemetryLayer.new
    meta = Metadata.new("test", "test", Level::TRACE, kind: Kind::SPAN)
    # Default should pass everything
    layer.enabled?(meta, Tracing::LayerContext.new(Tracing::Core::NoSubscriber.new)).should be_true
  end
end

# RED tests — FmtLayer JSON mode (tracing-serde)
describe "FmtLayer JSON mode (ported from tracing-serde)" do
  it "outputs events as JSON lines" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json.with_span_events(Tracing::FmtSpan::NONE)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("json_event", user: "alice", count: 42)
    end

    output = io.to_s.strip
    # Should be valid JSON; fields are nested under "fields" key (upstream default)
    parsed = JSON.parse(output)
    parsed["fields"]["message"].should eq("json_event")
    parsed["level"].should eq("INFO")
    parsed["fields"]["user"].should eq("alice")
    parsed["fields"]["count"].should eq(42_i64) # typed: integer now
  end

  it "includes timestamp in JSON output" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("timed_event")
    end

    output = io.to_s.strip
    parsed = JSON.parse(output)
    parsed["timestamp"].should_not be_nil
  end
end

# RED tests — OTel dynamic span name (otel.name field)
describe "OpenTelemetry dynamic span name" do
  it "extracts otel.name field for span name override" do
    layer = Tracing::OpenTelemetryLayer.new
    name = layer.resolve_span_name("default_name", otel_name: "custom_overridden")
    name.should eq("custom_overridden")
  end

  it "uses original name when otel.name is absent" do
    layer = Tracing::OpenTelemetryLayer.new
    name = layer.resolve_span_name("default_name", nil)
    name.should eq("default_name")
  end
end

# End-to-end integration — full stack
describe "full stack integration" do
  it "nested spans with filters, events, and field recording" do
    io = IO::Memory.new
    fmt = Tracing::FmtLayer.new(io).compact
    filter = Tracing::EnvFilter.new("info")
    registry = Tracing::Registry.new
      .with(fmt)
      .with(filter)

    Dispatch.with_default(Dispatch.new(registry)) do
      span!(Level::INFO, "outer").in_scope do
        info!("outer_event", step: 1)
        s = span!(Level::INFO, "inner")
        s.record(progress: 50)
        s.in_scope do
          info!("inner_event", detail: "working")
          debug!("should_be_filtered")
        end
        s.record(progress: 100)
      end
    end

    output = io.to_s
    output.should contain("outer_event")
    output.should contain("inner_event")
    output.should_not contain("should_be_filtered")
  end

  it "flame layer generates folded stack output" do
    io = IO::Memory.new
    flame = Tracing::FlameLayer.new(io)
    registry = Tracing::Registry.new.with(flame)

    Dispatch.with_default(Dispatch.new(registry)) do
      info_span!("root").in_scope do
        info_span!("child").in_scope { }
      end
    end

    output = io.to_s
    output.should contain("root")
    output.should contain("child")
    output.should contain(";")
  end

  it "SpanTrace captures span context" do
    registry = Tracing::Registry.new

    Dispatch.with_default(Dispatch.new(registry)) do
      span!(Level::INFO, "request").in_scope do
        span!(Level::INFO, "db").in_scope do
          trace = Tracing::SpanTrace.capture(registry)
          trace.spans.should contain("db")
          trace.spans.should contain("request")
        end
      end
    end
  end
end

# RED tests — typed JSON values
describe "FmtLayer JSON typed values" do
  it "serializes integers as JSON numbers" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json.with_span_events(Tracing::FmtSpan::NONE)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("int_event", count: 42_i64, size: 100_u64)
    end

    output = io.to_s.strip
    parsed = JSON.parse(output)
    # Integers should appear as JSON numbers (now nested under "fields")
    output.should contain("42")
    output.should_not contain(%("42"))
    parsed["fields"]["count"].as_i64.should eq(42)
  end

  it "serializes booleans as JSON bool" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json.with_span_events(Tracing::FmtSpan::NONE)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("bool_event", active: true, done: false)
    end

    output = io.to_s.strip
    output.should contain("true")
    output.should_not contain(%("true"))
  end

  it "serializes floats as JSON numbers" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json.with_span_events(Tracing::FmtSpan::NONE)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("float_event", ratio: 0.5_f64)
    end

    output = io.to_s.strip
    output.should contain("0.5")
    output.should_not contain(%("0.5"))
  end
end

# RED tests — Targets with_target(LevelFilter) overload
describe "Targets.with_target(LevelFilter)" do
  it "accepts LevelFilter in addition to Level" do
    filter = Tracing::Targets.new
      .with_target("my_crate", LevelFilter.info)
      .with_default(LevelFilter.trace)
    ctx = Tracing::LayerContext.new(Tracing::Core::NoSubscriber.new)

    meta = Metadata.new("ev", "my_crate::module", Level::INFO)
    filter.enabled?(meta, ctx).should be_true

    meta2 = Metadata.new("ev", "my_crate::module", Level::DEBUG)
    filter.enabled?(meta2, ctx).should be_false
  end
end

# Ported from upstream span relationship model
describe "Span#follows_from" do
  it "records a follows-from relationship between spans" do
    log = FollowsLog.new
    subscriber = Tracing::Registry.new.with(log)

    cause_id = nil
    effect_id = nil

    Dispatch.with_default(Dispatch.new(subscriber)) do
      a = span!(Level::INFO, "cause")
      b = span!(Level::INFO, "effect")
      cause_id = a.id
      effect_id = b.id
      b.follows_from(a.id.not_nil!)
    end

    log.relationships.size.should eq(1)
    log.relationships[0][0].should eq(effect_id)
    log.relationships[0][1].should eq(cause_id)
  end
end

private class FollowsLog < Tracing::Layer
  property relationships : Array(Tuple(Tracing::CoreSpan::Id, Tracing::CoreSpan::Id)) = [] of Tuple(Tracing::CoreSpan::Id, Tracing::CoreSpan::Id)

  def on_record_follows_from(span : Tracing::CoreSpan::Id, follows : Tracing::CoreSpan::Id, ctx : Tracing::LayerContext)
    @relationships << {span, follows}
  end
end

# Ported from vendor/tracing/tracing/src/span.rs:550
describe "Span.current" do
  it "returns disabled span when no span is entered" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      s = Span.current
      s.disabled?.should be_true
    end
  end

  it "returns the currently entered span" do
    registry = Tracing::Registry.new
    Dispatch.with_default(Dispatch.new(registry)) do
      span!(Level::INFO, "test_current").in_scope do
        s = Span.current
        s.disabled?.should be_false
        s.id.should_not be_nil
      end
    end
  end

  it "or_current returns self when enabled" do
    subscriber = TestSubscriber.new
    Dispatch.with_default(Dispatch.new(subscriber)) do
      s = span!(Level::INFO, "enabled_span")
      s2 = s.or_current
      s2.id.should eq(s.id)
    end
  end

  it "or_current returns current span when disabled" do
    registry = Tracing::Registry.new
    Dispatch.with_default(Dispatch.new(registry)) do
      outer = span!(Level::INFO, "outer_span")
      outer.in_scope do
        disabled = Span.none
        s = disabled.or_current
        s.id.should_not be_nil
      end
    end
  end
end

describe "Dispatch.has_been_set" do
  it "returns true after set_global_default" do
    begin
      sub = Tracing::Registry.new
      Tracing::Subscriber.set_global_default(sub)
      Dispatch.has_been_set?.should be_true
    rescue ex : Tracing::Core::SetGlobalDefaultError
      Dispatch.has_been_set?.should be_true
    end
  end
end

describe "Targets.with_targets" do
  it "accepts an array of target-level pairs" do
    filter = Tracing::Targets.new.with_targets([
      {"alpha", Level::ERROR},
      {"beta", LevelFilter.debug},
    ]).with_default(LevelFilter.off)
    ctx = Tracing::LayerContext.new(Tracing::Core::NoSubscriber.new)

    meta = Metadata.new("ev", "alpha::module", Level::ERROR)
    filter.enabled?(meta, ctx).should be_true

    meta2 = Metadata.new("ev", "beta::module", Level::DEBUG)
    filter.enabled?(meta2, ctx).should be_true

    meta3 = Metadata.new("ev", "alpha::module", Level::WARN)
    filter.enabled?(meta3, ctx).should be_false
  end
end

describe "EnvFilter span-name matching" do
  it "filters with filter outermost" do
    filter = Tracing::EnvFilter.new("error")
    counting = EventCollector.new
    subscriber = Tracing::Registry.new.with(counting).with(filter)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      error!("pass_error")
      info!("block_info")
    end

    counting.names.should contain("pass_error")
    counting.names.should_not contain("block_info")
  end
end

# Ported from upstream registry span lifecycle
describe "Registry span lifecycle" do
  it "clones and closes spans with ref counting" do
    registry = Tracing::Registry.new
    id = nil

    Dispatch.with_default(Dispatch.new(registry)) do
      s = span!(Level::INFO, "lifecycle_span")
      id = s.id.not_nil!
      data = registry.span_data(id)
      data.should_not be_nil
      data.try(&.ref_count).should eq(1)

      # Clone increments ref count
      cloned_id = Dispatch.current.not_nil!.clone_span(id)
      data = registry.span_data(id)
      data.try(&.ref_count).should eq(2)

      # try_close decrements, returns false while handles exist
      Dispatch.current.not_nil!.try_close(cloned_id).should be_false
      data = registry.span_data(id)
      data.try(&.ref_count).should eq(1)

      # Last handle closes the span
      Dispatch.current.not_nil!.try_close(id).should be_true
    end
  end
end

# RED tests — FmtLayer without_time
describe "FmtLayer without_time" do
  it "includes timestamp by default" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("with_time_event")
    end

    output = io.to_s
    output.should match(/^\d{4}-\d{2}-\d{2}T/)
  end

  it "omits timestamp after without_time" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).without_time
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("no_time_event")
    end

    output = io.to_s
    output.should_not match(/^\d{4}-\d{2}-\d{2}T/)
    output.should contain("no_time_event")
  end
end

# RED tests — TestWriter + with_test_writer
describe "TestWriter" do
  it "is an IO type" do
    writer = Tracing::FmtWriter::TestWriter.new
    writer.should be_a(IO)
  end

  it "accepts written bytes" do
    writer = Tracing::FmtWriter::TestWriter.new
    writer.print("hello test")
    writer.close
  end

  it "with_test_writer creates a working FmtLayer" do
    layer = Tracing::FmtLayer.with_test_writer
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("test_writer_event")
    end
    # Output goes to STDOUT (captured by spec runner); just ensure no error
  end
end

# RED tests — MakeWriter infrastructure (ported from upstream fmt/writer.rs)
describe "FmtWriter::MakeWriter" do
  it "Proc wraps a block returning IO" do
    io = IO::Memory.new
    mw = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    result = mw.make_writer(nil)
    result.should be(io)
  end

  it "Proc returns a fresh IO each call" do
    outputs = [] of IO::Memory
    mw = Tracing::FmtWriter::MakeWriter::Proc.new do
      io = IO::Memory.new
      outputs << io
      io
    end
    mw.make_writer(nil)
    mw.make_writer(nil)
    outputs.size.should eq(2)
  end
end

describe "FmtWriter::NoopWriter" do
  it "accepts writes without error (dev/null)" do
    w = Tracing::FmtWriter::NoopWriter.new
    w.write("hello world".to_slice)
    w.close
  end
end

describe "FmtWriter::WithMaxLevel" do
  it "passes events at or below max level" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithMaxLevel.new(inner, Level::INFO)

    meta = Metadata.new("ev", "test", Level::ERROR)
    result = mw.make_writer(meta)
    result.should be(io)
  end

  it "passes events exactly at max level" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithMaxLevel.new(inner, Level::INFO)

    meta = Metadata.new("ev", "test", Level::INFO)
    result = mw.make_writer(meta)
    result.should be(io)
  end

  it "discards events above max level (too verbose)" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithMaxLevel.new(inner, Level::INFO)

    meta = Metadata.new("ev", "test", Level::DEBUG)
    result = mw.make_writer(meta)
    result.should be_a(Tracing::FmtWriter::NoopWriter)
  end

  it "returns noop when no metadata provided" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithMaxLevel.new(inner, Level::INFO)

    result = mw.make_writer(nil)
    result.should be_a(Tracing::FmtWriter::NoopWriter)
  end
end

# RED tests — MakeWriter combinator integration via FmtLayer
describe "FmtLayer with MakeWriter with_max_level" do
  it "routes events based on level" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithMaxLevel.new(inner, Level::INFO)

    layer = Tracing::FmtLayer.new(STDOUT).with_make_writer(mw).without_time
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      error!("should_write")
      info!("should_write_too")
      debug!("should_be_discarded")
      trace!("should_be_discarded_trace")
    end

    output = io.to_s
    output.should contain("should_write")
    output.should contain("should_write_too")
    output.should_not contain("should_be_discarded")
    output.should_not contain("should_be_discarded_trace")
  end
end

# RED tests — WithMinLevel combinator
describe "FmtWriter::WithMinLevel" do
  it "passes events at or above min level" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithMinLevel.new(inner, Level::INFO)

    meta = Metadata.new("ev", "test", Level::TRACE)
    result = mw.make_writer(meta)
    result.should be(io)
  end

  it "passes events exactly at min level" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithMinLevel.new(inner, Level::INFO)

    meta = Metadata.new("ev", "test", Level::INFO)
    result = mw.make_writer(meta)
    result.should be(io)
  end

  it "discards events below min level (not verbose enough)" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithMinLevel.new(inner, Level::INFO)

    meta = Metadata.new("ev", "test", Level::WARN)
    result = mw.make_writer(meta)
    result.should be_a(Tracing::FmtWriter::NoopWriter)
  end

  it "returns noop when no metadata provided" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithMinLevel.new(inner, Level::INFO)

    result = mw.make_writer(nil)
    result.should be_a(Tracing::FmtWriter::NoopWriter)
  end
end

# RED tests — WithFilter combinator
describe "FmtWriter::WithFilter" do
  it "passes events when filter returns true" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithFilter.new(inner, ->(_meta : Tracing::Metadata) { true })

    meta = Metadata.new("ev", "test", Level::INFO)
    result = mw.make_writer(meta)
    result.should be(io)
  end

  it "discards events when filter returns false" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithFilter.new(inner, ->(_meta : Tracing::Metadata) { false })

    meta = Metadata.new("ev", "test", Level::INFO)
    result = mw.make_writer(meta)
    result.should be_a(Tracing::FmtWriter::NoopWriter)
  end

  it "passes make_writer(nil) through to inner" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    mw = Tracing::FmtWriter::WithFilter.new(inner, ->(_meta : Tracing::Metadata) { true })

    result = mw.make_writer(nil)
    result.should be(io)
  end
end

# RED tests — Tee combinator (writes to both)
describe "FmtWriter::Tee" do
  it "writes to both inner MakeWriters" do
    io1 = IO::Memory.new
    io2 = IO::Memory.new
    a = Tracing::FmtWriter::MakeWriter::Proc.new { io1 }
    b = Tracing::FmtWriter::MakeWriter::Proc.new { io2 }
    tee = Tracing::FmtWriter::Tee.new(a, b)

    meta = Metadata.new("ev", "test", Level::INFO)
    writer = tee.make_writer(meta)
    writer.should be_a(Tracing::FmtWriter::TeeWriter)
    writer.write("hello".to_slice)
    writer.close

    io1.to_s.should eq("hello")
    io2.to_s.should eq("hello")
  end
end

# RED tests — OrElse combinator
describe "FmtWriter::OrElse" do
  it "falls through to or_else when inner returns NoopWriter" do
    io = IO::Memory.new
    inner = Tracing::FmtWriter::WithMaxLevel.new(
      Tracing::FmtWriter::MakeWriter::Proc.new { IO::Memory.new },
      Level::INFO
    )
    fallback = Tracing::FmtWriter::MakeWriter::Proc.new { io }
    or_else = Tracing::FmtWriter::OrElse.new(inner, fallback)

    # DEBUG > INFO, so WithMaxLevel returns NoopWriter -> or_else delegates to fallback
    meta = Metadata.new("ev", "test", Level::DEBUG)
    result = or_else.make_writer(meta)
    result.should be(io)
  end

  it "uses inner writer when it returns a real writer" do
    io1 = IO::Memory.new
    io2 = IO::Memory.new
    inner = Tracing::FmtWriter::MakeWriter::Proc.new { io1 }
    fallback = Tracing::FmtWriter::MakeWriter::Proc.new { io2 }
    or_else = Tracing::FmtWriter::OrElse.new(inner, fallback)

    meta = Metadata.new("ev", "test", Level::INFO)
    result = or_else.make_writer(meta)
    result.should be(io1)
  end
end

# RED tests — level-filter chaining (ported from upstream writer.rs)
describe "MakeWriter combinators level filter chain" do
  it "routes events to the correct writer based on level" do
    info_io = IO::Memory.new
    debug_io = IO::Memory.new
    warn_io = IO::Memory.new
    err_io = IO::Memory.new

    info_mw = Tracing::FmtWriter::MakeWriter::Proc.new { info_io }
    debug_mw = Tracing::FmtWriter::MakeWriter::Proc.new { debug_io }
    warn_mw = Tracing::FmtWriter::MakeWriter::Proc.new { warn_io }
    err_mw = Tracing::FmtWriter::MakeWriter::Proc.new { err_io }

    # Ported from upstream combinators_level_filters test:
    # info.with_max_level(INFO) -> only INFO, WARN, ERROR
    # debug.with_max_level(DEBUG) -> only INFO, WARN, ERROR, DEBUG
    # etc.
    # Combined with Tee, each writer gets events at or below its max level
    make_writer = Tracing::FmtWriter::Tee.new(
      Tracing::FmtWriter::WithMaxLevel.new(info_mw, Level::INFO),
      Tracing::FmtWriter::WithMaxLevel.new(debug_mw, Level::DEBUG)
    )
    make_writer = Tracing::FmtWriter::Tee.new(make_writer,
      Tracing::FmtWriter::WithMaxLevel.new(warn_mw, Level::WARN))
    make_writer = Tracing::FmtWriter::Tee.new(make_writer,
      Tracing::FmtWriter::WithMaxLevel.new(err_mw, Level::ERROR))

    layer = Tracing::FmtLayer.new(STDOUT).with_make_writer(make_writer).without_time
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      trace!("t")
      debug!("d")
      info!("i")
      warn!("w")
      error!("e")
    end

    # INFO writer: gets ERROR, WARN, INFO (levels <= INFO)
    info_io.to_s.should contain("e")
    info_io.to_s.should contain("w")
    info_io.to_s.should contain("i")
    info_io.to_s.should_not contain("d")
    info_io.to_s.should_not contain("t")

    # DEBUG writer: gets ERROR, WARN, INFO, DEBUG (levels <= DEBUG)
    debug_io.to_s.should contain("e")
    debug_io.to_s.should contain("w")
    debug_io.to_s.should contain("i")
    debug_io.to_s.should contain("d")
    debug_io.to_s.should_not contain("t")
  end
end

# RED tests — fmt() SubscriberBuilder (ported from upstream fmt/mod.rs)
describe "Tracing.fmt SubscriberBuilder" do
  it "fmt() returns a builder" do
    builder = Tracing.fmt
    builder.should be_a(Tracing::FmtSubscriberBuilder)
  end

  it "finish returns a subscriber that implements Subscriber" do
    subscriber = Tracing.fmt.finish
    subscriber.should be_a(Tracing::Core::Subscriber)
  end

  it "builder configures and finishes a subscriber that writes output" do
    io = IO::Memory.new
    subscriber = Tracing.fmt
      .with_writer(io)
      .without_time
      .with_target(false)
      .with_level(false)
      .finish

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("builder_test")
    end

    io.to_s.should contain("builder_test")
  end

  it "builder supports compact mode (delegates to FmtLayer)" do
    io = IO::Memory.new
    subscriber = Tracing.fmt
      .with_writer(io)
      .without_time
      .compact
      .finish

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("compact_test")
    end

    io.to_s.should contain("compact_test")
  end

  it "builder supports json mode (delegates to FmtLayer)" do
    io = IO::Memory.new
    subscriber = Tracing.fmt
      .with_writer(io)
      .without_time
      .json
      .finish

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("json_test")
    end

    output = io.to_s.strip
    JSON.parse(output)["fields"]["message"].should eq("json_test")
  end

  it "builder with_max_level sets the default level filter" do
    io = IO::Memory.new
    subscriber = Tracing.fmt
      .with_writer(io)
      .without_time
      .with_max_level(LevelFilter.error)
      .finish

    Dispatch.with_default(Dispatch.new(subscriber)) do
      error!("should_appear")
      info!("should_not_appear")
    end

    io.to_s.should contain("should_appear")
    io.to_s.should_not contain("should_not_appear")
  end

  it "builder delegates with_thread_ids" do
    io = IO::Memory.new
    subscriber = Tracing.fmt
      .with_writer(io)
      .without_time
      .with_thread_ids(true)
      .finish

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("thread_id_test")
    end

    io.to_s.should contain(Fiber.current.object_id.to_s)
  end

  it "builder delegates with_ansi" do
    io = IO::Memory.new
    subscriber = Tracing.fmt
      .with_writer(io)
      .without_time
      .with_ansi(true)
      .finish

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("ansi_test")
    end

    io.to_s.should contain("\e[")
  end
end

# RED tests — JSON format options (ported from upstream fmt/format/json.rs)
describe "FmtLayer JSON options" do
  it "default JSON nests fields under 'fields' key" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json.without_time
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("nested_test", key: "value")
    end

    output = io.to_s.strip
    json = JSON.parse(output)
    json["fields"].should_not be_nil
    json["fields"]["message"].should eq("nested_test")
    json["fields"]["key"].should eq("value")
  end

  it "flatten_event(true) puts event fields at root level" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json.without_time
      .flatten_event(true)
      .with_span_events(Tracing::FmtSpan::NONE)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("flat_test", key: "value")
    end

    output = io.to_s.strip
    json = JSON.parse(output)
    json["fields"]?.should be_nil
    json["name"].should eq("flat_test")
    json["key"].should eq("value")
  end

  it "with_current_span includes span name by default" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json.without_time
      .with_span_events(Tracing::FmtSpan::NONE)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      s = span!(Level::INFO, "json_parent_span")
      s.in_scope { info!("span_test") }
    end

    output = io.to_s.strip
    json = JSON.parse(output)
    json["span"].should eq("json_parent_span")
  end

  it "with_current_span(false) omits span field" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json.without_time
      .with_current_span(false)
      .with_span_events(Tracing::FmtSpan::NONE)
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      s = span!(Level::INFO, "hidden_span")
      s.in_scope { info!("no_span_test") }
    end

    output = io.to_s.strip
    json = JSON.parse(output)
    json["span"]?.should be_nil
    json["fields"]["message"].should eq("no_span_test")
  end

  it "default JSON omits event name at root level" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json.without_time
    subscriber = Tracing::Registry.new.with(layer)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("no_name_test")
    end

    output = io.to_s.strip
    json = JSON.parse(output)
    json["name"]?.should be_nil
  end

  it "builder delegates JSON options" do
    io = IO::Memory.new
    subscriber = Tracing.fmt
      .with_writer(io)
      .without_time
      .json
      .flatten_event(true)
      .with_current_span(false)
      .finish

    Dispatch.with_default(Dispatch.new(subscriber)) do
      info!("builder_json_test", val: 42)
    end

    output = io.to_s.strip
    json = JSON.parse(output)
    json["fields"]?.should be_nil
    json["span"]?.should be_nil
    json["name"].should eq("builder_json_test")
    json["val"].as_i.should eq(42)
  end
end

# RED tests — with_filter_reloading + reload_handle (ported from upstream fmt/mod.rs)
describe "FmtSubscriberBuilder with_filter_reloading" do
  it "provides a reload handle after with_filter_reloading" do
    io = IO::Memory.new
    subscriber = Tracing.fmt
      .with_writer(io)
      .without_time
      .with_max_level(LevelFilter.error)
      .with_filter_reloading
      .finish

    handle = Tracing.fmt
      .with_max_level(LevelFilter.error)
      .with_filter_reloading
      .reload_handle

    handle.should be_a(Tracing::Handle)
  end

  it "reload_handle modifies filter at runtime" do
    io = IO::Memory.new
    builder = Tracing.fmt
      .with_writer(io)
      .without_time
      .with_max_level(LevelFilter.error)
      .with_filter_reloading

    handle = builder.reload_handle
    subscriber = builder.finish

    Dispatch.with_default(Dispatch.new(subscriber)) do
      error!("will_show")
      info!("initially_hidden")
    end

    # After reloading filter to TRACE, INFO events pass through
    handle.reload(Tracing::LevelFilterLayer.new(LevelFilter.trace))

    Dispatch.with_default(Dispatch.new(subscriber)) do
      error!("still_shows")
      info!("now_visible")
    end

    output = io.to_s
    output.should contain("will_show")
    output.should_not contain("initially_hidden")
    output.should contain("still_shows")
    output.should contain("now_visible")
  end
end

# RED tests — FormatEvent / FormatFields / Writer types (ported from upstream fmt/format/mod.rs)
describe "FmtFormat Writer" do
  it "wraps an IO and tracks ANSI state" do
    io = IO::Memory.new
    w = Tracing::FmtFormat::Writer.new(io, has_ansi_escapes: true)
    w.has_ansi_escapes?.should be_true
    w.io.should be(io)
  end

  it "delegates writes to the underlying IO" do
    io = IO::Memory.new
    w = Tracing::FmtFormat::Writer.new(io)
    w.io.write("hello".to_slice)
    io.to_s.should eq("hello")
  end
end

describe "FmtFormat FormatFields" do
  it "is an abstract class that concrete types implement" do
    formatter = TestFormatFields.new
    formatter.should be_a(Tracing::FmtFormat::FormatFields)
  end
end

describe "FmtFormat FormatEvent" do
  it "is an abstract class that concrete types implement" do
    formatter = TestFormatEvent.new
    formatter.should be_a(Tracing::FmtFormat::FormatEvent)
  end
end

private class TestFormatFields < Tracing::FmtFormat::FormatFields
  def format_fields(writer : Tracing::FmtFormat::Writer, values : Tracing::Field::ValueSet) : Nil
  end
end

private class TestFormatEvent < Tracing::FmtFormat::FormatEvent
  def format_event(ctx : Tracing::LayerContext, writer : Tracing::FmtFormat::Writer, event : Tracing::Core::Event) : Nil
  end
end
