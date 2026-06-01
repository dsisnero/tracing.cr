require "./spec_helper"
require "../src/tracing"
require "../src/tracing/concurrency/fiber_ext"

private alias Level = Tracing::Level
private alias Dispatch = Tracing::Dispatch

private class ExtCollector < Tracing::Layer
  property names : Array(String) = [] of String

  def on_event(event : Tracing::Core::Event, ctx : Tracing::LayerContext)
    @names << event.metadata.name
  end
end

describe "Fiber extensions" do
  it "Fiber.spawn_traced records events" do
    log = ExtCollector.new
    subscriber = Tracing::Registry.new.with(log)

    Dispatch.with_default(Dispatch.new(subscriber)) do
      fiber = Fiber.spawn_traced("traced_worker") do
        Tracing.info("inside_traced")
        42
      end
      fiber.await.should eq(42)
    end

    log.names.should contain("inside_traced")
  end
end
