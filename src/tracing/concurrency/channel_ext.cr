require "./channel"

class Channel(T)
  # Wrap this channel with tracing instrumentation.
  #
  # Opt-in via: require "tracing/concurrency/channel_ext"
  def traced(name : String = "channel") : Tracing::Concurrency::TracedChannel(T)
    Tracing::Concurrency::TracedChannel(T).new(self, name)
  end
end
