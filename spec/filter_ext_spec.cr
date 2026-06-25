require "./spec_helper"

# Ported from vendor/tracing/tracing-subscriber/src/filter/layer_filters/combinator.rs
# (FilterExt::and / ::or / ::not). The Crystal port collapses Rust's `Filter`
# trait into `Layer`, so these combine layers used as filters.
module FilterExtSpec
  alias Level = Tracing::Level
  alias LevelFilter = Tracing::LevelFilter
  alias Metadata = Tracing::Metadata
  alias Interest = Tracing::Callsite::Interest

  # A filter with a fixed `enabled?` result and `max_level_hint`.
  private class HintFilter < Tracing::Layer
    def initialize(@on : Bool, @hint : LevelFilter?)
    end

    def enabled?(metadata : Metadata, ctx : Tracing::LayerContext) : Bool
      @on
    end

    def max_level_hint : LevelFilter?
      @hint
    end
  end

  # A filter with a fixed callsite `Interest`.
  private class InterestFilter < Tracing::Layer
    def initialize(@interest : Interest)
    end

    def on_register_callsite(metadata : Metadata, ctx : Tracing::LayerContext) : Interest
      @interest
    end
  end

  describe "FilterExt (ported from layer_filters/combinator.rs)" do
    ctx = Tracing::LayerContext.new(Tracing::Core::NoSubscriber.new)
    foo = Tracing::FilterFn.new(&.target.starts_with?("foo"))
    low = Tracing::FilterFn.new { |meta| meta.level <= LevelFilter.info }

    describe "#and" do
      it "is enabled only when both filters are enabled" do
        both = low.and(foo)
        both.enabled?(Metadata.new("e", "foo::x", Level::INFO), ctx).should be_true
        both.enabled?(Metadata.new("e", "foo::x", Level::DEBUG), ctx).should be_false
        both.enabled?(Metadata.new("e", "bar", Level::INFO), ctx).should be_false
      end

      it "max_level_hint is the most restrictive of the two" do
        a = HintFilter.new(true, LevelFilter.info)
        b = HintFilter.new(true, LevelFilter.debug)
        a.and(b).max_level_hint.should eq(LevelFilter.info)
      end

      it "max_level_hint is nil if either hint is nil" do
        HintFilter.new(true, nil).and(HintFilter.new(true, LevelFilter.debug))
          .max_level_hint.should be_nil
      end

      it "callsite interest is never if either is never" do
        InterestFilter.new(Interest.always).and(InterestFilter.new(Interest.never))
          .on_register_callsite(Metadata.new("e", "x", Level::INFO), ctx).never?.should be_true
      end
    end

    describe "#or" do
      it "is enabled when either filter is enabled" do
        either = low.or(foo)
        either.enabled?(Metadata.new("e", "foo::x", Level::DEBUG), ctx).should be_true
        either.enabled?(Metadata.new("e", "bar", Level::INFO), ctx).should be_true
        either.enabled?(Metadata.new("e", "bar", Level::DEBUG), ctx).should be_false
      end

      it "max_level_hint is the least restrictive of the two" do
        a = HintFilter.new(true, LevelFilter.info)
        b = HintFilter.new(true, LevelFilter.debug)
        a.or(b).max_level_hint.should eq(LevelFilter.debug)
      end

      it "max_level_hint is nil if either hint is nil" do
        HintFilter.new(true, LevelFilter.info).or(HintFilter.new(true, nil))
          .max_level_hint.should be_nil
      end

      it "callsite interest is always if either is always" do
        InterestFilter.new(Interest.never).or(InterestFilter.new(Interest.always))
          .on_register_callsite(Metadata.new("e", "x", Level::INFO), ctx).always?.should be_true
      end
    end

    describe "#not" do
      it "inverts the wrapped filter" do
        inverted = foo.not
        inverted.enabled?(Metadata.new("e", "foo::x", Level::INFO), ctx).should be_false
        inverted.enabled?(Metadata.new("e", "bar", Level::INFO), ctx).should be_true
      end

      it "max_level_hint is nil" do
        HintFilter.new(true, LevelFilter.info).not.max_level_hint.should be_nil
      end

      it "callsite interest flips always<->never" do
        m = Metadata.new("e", "x", Level::INFO)
        InterestFilter.new(Interest.always).not.on_register_callsite(m, ctx).never?.should be_true
        InterestFilter.new(Interest.never).not.on_register_callsite(m, ctx).always?.should be_true
      end
    end
  end
end
