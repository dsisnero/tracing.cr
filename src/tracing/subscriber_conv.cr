module Tracing
  module Subscriber
    def self.with_default(subscriber : Core::Subscriber, & : -> T) : T forall T
      Dispatch.with_default(Dispatch.new(subscriber)) { yield }
    end

    # Port parity: matches upstream tracing::subscriber::set_global_default()
    # ameba:disable Naming/AccessorMethodName
    def self.set_global_default(subscriber : Core::Subscriber) : Nil
      Dispatch.global_default = Dispatch.new(subscriber)
    end
  end
end
