require "./spec_helper"

private alias Level = Tracing::Level
private alias LevelFilter = Tracing::LevelFilter
private alias ParseLevelError = Tracing::ParseLevelError
private alias ParseLevelFilterError = Tracing::ParseLevelFilterError
private alias Kind = Tracing::Kind
private alias Metadata = Tracing::Metadata
private alias Parent = Tracing::Parent
private alias Span = Tracing::Span

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

  describe "comparisons" do
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
    Kind::SPAN.is_span?.should be_true
    Kind::SPAN.is_event?.should be_false
  end

  it "EVENT is event" do
    Kind::EVENT.is_span?.should be_false
    Kind::EVENT.is_event?.should be_true
  end

  it "hint adds HINT bit" do
    k = Kind::SPAN.hint
    k.is_span?.should be_true
    k.is_hint?.should be_true
  end
end

describe Tracing::Core::Span::Id do
  it "constructs from non-zero u64" do
    id = Span::Id.from_u64(42_u64)
    id.into_u64.should eq(42_u64)
  end

  it "rejects zero" do
    expect_raises(ArgumentError) { Span::Id.from_u64(0_u64) }
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
    id = Span::Id.from_u64(10_u64)
    p = Parent.explicit(id)
    p.explicit?.should be_true
    p.id.should eq(id)
  end
end
