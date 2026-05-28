module Tracing
  module Core
    # A Dispatch represents the ability to dispatch spans and events
    # to a Subscriber.
    #
    # It wraps a Subscriber instance and provides static methods to
    # access the globally registered default subscriber.
    class Dispatch
      @subscriber : Subscriber?

      def initialize(@subscriber : Subscriber? = nil)
      end

      # Returns the contained subscriber, if any.
      def subscriber : Subscriber?
        @subscriber
      end

      # Set a global default Dispatch.
      #
      # This will be used as the fallback if no thread-local dispatch
      # has been set.
      def self.set_global_default(dispatch : Dispatch) : Bool
        @@global_default.set(dispatch)
        true
      end

      # Returns a reference to the globally set default dispatcher.
      def self.get_default : Dispatch?
        @@global_default.get?
      end

      # Try to close the global default dispatch, if it is set.
      def self.try_close : Bool
        @@global_default.try_close
      end

      # Returns the subscriber that should be used for dispatching.
      protected def self.current_subscriber : Subscriber?
        # In a full implementation, this would check thread-local
        # dispatchers first, then fall back to global default.
        get_default.try(&.subscriber)
      end

      private class GlobalDefault
        @@instance : GlobalDefault = GlobalDefault.new
        @dispatch : Dispatch?
        @closed : Bool = false
        @mutex : Mutex = Mutex.new(:reentrant)

        def self.set(dispatch : Dispatch) : Bool
          @@instance._set(dispatch)
        end

        def self.get? : Dispatch?
          @@instance._get?
        end

        def self.try_close : Bool
          @@instance._try_close
        end

        def _set(dispatch : Dispatch) : Bool
          @mutex.synchronize do
            return false if @closed
            @dispatch = dispatch
            true
          end
        end

        def _get? : Dispatch?
          @mutex.synchronize do
            @dispatch
          end
        end

        def _try_close : Bool
          @mutex.synchronize do
            return false if @closed
            @closed = true
            true
          end
        end
      end
    end
  end
end
