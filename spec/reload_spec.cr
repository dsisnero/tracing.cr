require "./spec_helper"

# Ported from vendor/tracing/tracing-subscriber/tests/reload.rs.
#
# Upstream verifies reload by counting which inner filter handles events
# before/after a reload (FILTER1_CALLS vs FILTER2_CALLS). We mirror that with
# recording layers. The upstream `LevelFilter::current()` assertions exercise
# the global interest-cache recompute; the Crystal port's `Dispatch.with_default`
# is fiber-local and does not register a global dispatcher, so that recompute is
# out of scope here (see reload.cr).
module ReloadSpec
  alias Level = Tracing::Level
  alias LevelFilter = Tracing::LevelFilter

  # Records processed event names and reports a fixed max-level hint, so the
  # active inner layer can be observed across a reload.
  private class RecordingLayer < Tracing::Layer
    getter names = [] of String
    @hint : LevelFilter

    def initialize(@hint : LevelFilter)
    end

    def on_event(event : Tracing::Core::Event, ctx : Tracing::LayerContext) : Nil
      @names << event.metadata.name
    end

    def max_level_hint : LevelFilter?
      @hint
    end
  end

  describe "Reload (ported from reload.rs)" do
    it "swaps the active inner layer via handle.reload (reload_handle)" do
      one = RecordingLayer.new(LevelFilter.info)
      two = RecordingLayer.new(LevelFilter.debug)
      reload, handle = Tracing::Reload.new(one)
      subscriber = Tracing::Registry.new.with(reload)

      Tracing::Dispatch.with_default(Tracing::Dispatch.new(subscriber)) do
        Tracing.event(Level::INFO, "first")
        one.names.should eq(["first"])
        two.names.should be_empty

        handle.reload(two)

        Tracing.event(Level::INFO, "second")
        one.names.should eq(["first"])
        two.names.should eq(["second"])
      end
    end

    it "delegates max_level_hint to the current inner layer" do
      reload, handle = Tracing::Reload.new(RecordingLayer.new(LevelFilter.info))
      reload.max_level_hint.should eq(LevelFilter.info)
      handle.reload(RecordingLayer.new(LevelFilter.debug))
      reload.max_level_hint.should eq(LevelFilter.debug)
    end

    it "mutates the inner layer in place via handle.modify" do
      one = RecordingLayer.new(LevelFilter.info)
      reload, handle = Tracing::Reload.new(one)
      handle.modify { |inner| inner.as(RecordingLayer).names << "injected" }
      one.names.should eq(["injected"])
    end

    it "borrows the current inner via handle.with_current" do
      reload, handle = Tracing::Reload.new(RecordingLayer.new(LevelFilter.warn))
      handle.with_current(&.max_level_hint).should eq(LevelFilter.warn)
    end

    it "exposes additional handles via #handle" do
      reload, _ = Tracing::Reload.new(RecordingLayer.new(LevelFilter.info))
      extra = reload.handle
      extra.reload(RecordingLayer.new(LevelFilter.trace))
      reload.max_level_hint.should eq(LevelFilter.trace)
    end
  end
end
