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
  # Inverted comparisons: TRACE(0) > DEBUG(1) > INFO(2) > WARN(3) > ERROR(4)
  # Filter passes events at-or-below its threshold
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
    dispatch = Dispatch.new(subscriber)
    Dispatch.global_default = dispatch

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

# Test subscriber for verifying dispatch lifecycle
private class TestSubscriber
  include Subscriber

  property entered_count : Int32 = 0
  property exited_count : Int32 = 0
  property new_span_count : Int32 = 0

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
