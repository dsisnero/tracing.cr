module Tracing
  module Core
    # A Dispatch represents the ability to dispatch spans and events
    # to a Subscriber.
    class Dispatch
      @subscriber : Subscriber?

      def initialize(@subscriber : Subscriber? = nil)
      end

      def subscriber : Subscriber?
        @subscriber
      end

      def self.global_default=(dispatch : Dispatch) : Nil
        @@global_default.set(dispatch)
      end

      def self.default : Dispatch?
        @@global_default.get?
      end

      def self.try_close : Bool
        @@global_default.try_close
      end

      protected def self.current_subscriber : Subscriber?
        default.try(&.subscriber)
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
