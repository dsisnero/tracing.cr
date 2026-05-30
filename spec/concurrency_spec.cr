require "./spec_helper"
require "../src/tracing/concurrency"

private alias Level = Tracing::Level

private class FiberCollector < Tracing::Layer
  property names : Array(String) = [] of String

  def on_event(event : Tracing::Core::Event, ctx : Tracing::LayerContext)
    @names << event.metadata.name
  end
end

describe Tracing::Concurrency do
  it "spawned fiber records events to the subscriber" do
    log = FiberCollector.new
    subscriber = Tracing::Registry.new.with(log)

    Tracing::Dispatch.with_default(Tracing::Dispatch.new(subscriber)) do
      chan = Tracing::Concurrency.spawn("worker") do
        Tracing.info("inside_fiber")
        42
      end
      chan.receive.should eq(42)
    end

    log.names.should contain("inside_fiber")
  end

  it "propagates span context to spawned fiber" do
    log = FiberCollector.new
    subscriber = Tracing::Registry.new.with(log)

    Tracing::Dispatch.with_default(Tracing::Dispatch.new(subscriber)) do
      info_span!("parent_span").in_scope do
        chan = Tracing::Concurrency.spawn("worker") do
          Tracing.info("inside_fiber_with_span")
        end
        chan.receive
      end
    end

    log.names.should contain("inside_fiber_with_span")
  end
end
