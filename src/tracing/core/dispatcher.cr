module Tracing
  module Core
    # Manages the set of active dispatchers and triggers callsite
    # interest cache rebuilding when dispatchers change.
    module Dispatchers
      class_getter instance : Manager = Manager.new

      class Manager
        @dispatchers : Array(Dispatch)
        @has_just_one : Atomic(Bool)
        @mutex : Mutex

        def initialize
          @dispatchers = [] of Dispatch
          @has_just_one = Atomic(Bool).new(true)
          @mutex = Mutex.new(:reentrant)
        end

        def register(dispatch : Dispatch) : Nil
          @mutex.synchronize do
            @dispatchers << dispatch
            @has_just_one.set(@dispatchers.size <= 1, :sequentially_consistent)
          end
          dispatch.on_register_dispatch
          Dispatchers.rebuild_interest_cache
        end

        def each(& : Dispatch ->) : Nil
          @mutex.synchronize do
            @dispatchers.each { |dispatch| yield dispatch }
          end
        end
      end

      # Rebuild interest for all registered callsites based on
      # current dispatchers.
      def self.rebuild_interest_cache : Nil
        max_level = LevelFilter.off

        instance.each do |dispatch|
          hint = dispatch.max_level_hint || LevelFilter.trace
          max_level = hint if hint > max_level
        end

        Callsite::Callsites.instance.each do |callsite|
          meta = callsite.metadata
          interest : Callsite::Interest? = nil

          instance.each do |dispatch|
            i = dispatch.register_callsite(meta)
            interest = interest ? interest.and(i) : i
          end

          callsite.interest = interest || Callsite::Interest.never
        end

        LevelFilter.max = max_level
      end
    end

    # A Dispatch wraps a Subscriber and provides the interface for
    # dispatching trace data.
    class Dispatch
      @subscriber : Subscriber?

      def initialize(@subscriber : Subscriber? = nil)
      end

      def subscriber : Subscriber?
        @subscriber
      end

      # Set the global default dispatch. Triggers callsite interest
      # cache rebuild. Returns true on success, false if already set.
      def self.global_default=(dispatch : Dispatch) : Nil
        return if @@global_init.get(:sequentially_consistent) == INITIALIZED

        if @@global_init.compare_and_set(UNINITIALIZED, INITIALIZING, :sequentially_consistent, :sequentially_consistent)
          @@global_dispatch = dispatch
          @@global_init.set(INITIALIZED, :sequentially_consistent)
          Dispatchers.instance.register(dispatch)
        else
          raise SetGlobalDefaultError.new
        end
      end

      def self.default : Dispatch?
        @@global_init.get(:sequentially_consistent) == INITIALIZED ? @@global_dispatch : nil
      end

      def self.try_close : Bool
        return false if @@global_init.get(:acquire) == INITIALIZED
        @@global_init.compare_and_set(UNINITIALIZED, INITIALIZING, :acquire_release, :acquire)
      end

      # Temporarily set this dispatch as the default for the current fiber.
      #
      # Usage:
      #   Dispatch.with_default(my_dispatch) do
      #     # my_dispatch is the default here
      #   end
      def self.with_default(dispatch : Dispatch, & : -> T) : T forall T
        prior = fiber_local
        store_fiber_local(dispatch)
        begin
          yield
        ensure
          store_fiber_local(prior)
        end
      end

      # Get the currently active dispatch (fiber-local first, then global).
      def self.current : Dispatch?
        fiber_local || default
      end

      # Dispatch methods — forward to the contained subscriber.

      def new_span(attrs : Span::Attributes) : Span::Id
        s = @subscriber || return Span::Id.from_u64(1)
        s.new_span(attrs)
      end

      def enter(id : Span::Id) : Nil
        @subscriber.try(&.enter(id))
      end

      def exit(id : Span::Id) : Nil
        @subscriber.try(&.exit(id))
      end

      def event(event : Event) : Nil
        @subscriber.try(&.event(event))
      end

      def record(id : Span::Id, values : Span::Record) : Nil
        @subscriber.try(&.record(id, values))
      end

      def record_follows_from(span : Span::Id, follows : Span::Id) : Nil
        @subscriber.try(&.record_follows_from(span, follows))
      end

      def enabled(metadata : Metadata) : Bool
        @subscriber.try(&.enabled(metadata)) || false
      end

      def register_callsite(metadata : Metadata) : Callsite::Interest
        @subscriber.try(&.register_callsite(metadata)) || Callsite::Interest.sometimes
      end

      def max_level_hint : LevelFilter?
        @subscriber.try(&.max_level_hint)
      end

      def current_span : Core::Span::Current
        @subscriber.try(&.current_span) || Core::Span::Current.unknown
      end

      def on_register_dispatch : Nil
      end

      private UNINITIALIZED = 0_u8
      private INITIALIZING  = 1_u8
      private INITIALIZED   = 2_u8

      @@global_init : Atomic(UInt8) = Atomic(UInt8).new(UNINITIALIZED)
      @@global_dispatch : Dispatch?
      @@fiber_locals = {} of Fiber => Dispatch

      private def self.fiber_local : Dispatch?
        @@fiber_locals[Fiber.current]?
      end

      private def self.store_fiber_local(dispatch : Dispatch?) : Nil
        if dispatch
          @@fiber_locals[Fiber.current] = dispatch
        else
          @@fiber_locals.delete(Fiber.current)
        end
      end
    end

    class SetGlobalDefaultError < Exception
      def initialize
        super("the global default subscriber has already been set")
      end
    end
  end
end
