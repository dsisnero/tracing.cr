require "./spec_helper"
require "../src/tracing/concurrency"

private alias Level = Tracing::Level
private alias Dispatch = Tracing::Dispatch

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

  it "spawn_with_span attaches a specific span to the fiber" do
    log = FiberCollector.new
    subscriber = Tracing::Registry.new.with(log)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      s = span!(Level::INFO, "custom_span", tag: "concurrency")
      chan = Tracing::Concurrency.spawn_with_span(s) do
        Tracing.info("inside_custom_span")
      end
      chan.receive
    end

    log.names.should contain("inside_custom_span")
  end

  it "with_subscriber uses a specific subscriber in the fiber" do
    log_a = FiberCollector.new
    log_b = FiberCollector.new
    sub_a = Tracing::Registry.new.with(log_a)
    sub_b = Tracing::Registry.new.with(log_b)

    Tracing::Dispatch.with_default(Tracing::Dispatch.new(sub_a)) do
      chan = Tracing::Concurrency.with_subscriber(sub_b) do
        Tracing.info("routed_to_b")
        99
      end
      chan.receive.should eq(99)
    end

    log_a.names.should be_empty
    log_b.names.should contain("routed_to_b")
  end
end
