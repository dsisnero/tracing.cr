require "./fiber"

module Tracing::Concurrency
  # A Channel(T) wrapper that emits tracing events on send/receive.
  class TracedChannel(T)
    @channel : Channel(T)
    @name : String

    def initialize(@channel : Channel(T), @name : String = "channel")
    end

    def send(value : T) : Nil
      Tracing.info("channel.send", channel: @name, value: value)
      @channel.send(value)
    end

    def receive : T
      result = @channel.receive
      Tracing.info("channel.receive", channel: @name, value: result)
      result
    end

    def receive? : T?
      result = @channel.receive?
      Tracing.info("channel.receive", channel: @name, value: result) if result
      result
    end
  end
end
