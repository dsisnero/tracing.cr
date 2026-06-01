require "./spec_helper"
require "../src/tracing"
require "../src/tracing/concurrency/channel_ext"

private class ChCollector < Tracing::Layer
  property names : Array(String) = [] of String

  def on_event(event : Tracing::Core::Event, ctx : Tracing::LayerContext)
    @names << event.metadata.name
  end
end

describe "Channel extensions" do
  it "Channel#traced wraps channel with tracing" do
    log = ChCollector.new
    subscriber = Tracing::Registry.new.with(log)

    Tracing::Dispatch.with_default(Tracing::Dispatch.new(subscriber)) do
      ch = Channel(Int32).new(1).traced("my_queue")
      ch.send(42)
      ch.receive.should eq(42)
    end

    log.names.should contain("channel.send")
    log.names.should contain("channel.receive")
  end
end
