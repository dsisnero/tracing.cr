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

    # Tries to install the subscriber as the global default.
    # Returns true on success, false if a global default is already set.
    #
    # Ported from upstream `tracing_subscriber::util::SubscriberInitExt::try_init`.
    def self.try_init(subscriber : Core::Subscriber) : Bool
      return false if Dispatch.has_been_set?
      set_global_default(subscriber)
      true
    end
  end
end
