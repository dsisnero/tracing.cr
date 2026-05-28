module Tracing
  module Core
    module Callsite
      # Trait implemented by callsites.
      module Interface
        abstract def interest=(interest : Interest) : Nil
        abstract def metadata : Metadata
      end

      # A default ready-made callsite implementation.
      class DefaultCallsite
        include Interface

        UNREGISTERED = 0_u8
        REGISTERING  = 1_u8
        REGISTERED   = 2_u8

        getter metadata : Metadata

        @interest : Atomic(UInt8)
        @registration : Atomic(UInt8)
        @next_ptr : Atomic(UInt64)

        def initialize(@metadata : Metadata = Metadata.new("", "", Level::INFO))
          @interest = Atomic(UInt8).new(0xFF_u8)
          @registration = Atomic(UInt8).new(UNREGISTERED)
          @next_ptr = Atomic(UInt64).new(0_u64)
        end

        def interest : Interest
          val = @interest.get(:relaxed)
          case val
          when Interest::NEVER.value     then Interest.never
          when Interest::ALWAYS.value    then Interest.always
          when Interest::SOMETIMES.value then Interest.sometimes
          else
            # Will register lazily when dispatch is available
            Interest.sometimes
          end
        end

        def interest=(interest : Interest) : Nil
          @interest.set(interest.value, :sequentially_consistent)
        end

        # Attempt lazy registration. Called externally when dispatchers are available.
        def try_register : Interest
          cmp = UNREGISTERED
          if @registration.compare_and_set(cmp, REGISTERING, :acquire_release, :acquire)
            Callsites.instance.push_default(self)
            @registration.set(REGISTERED, :release)
          elsif @registration.get(:acquire) == REGISTERING
            return Interest.sometimes
          end

          val = @interest.get(:relaxed)
          case val
          when Interest::NEVER.value  then Interest.never
          when Interest::ALWAYS.value then Interest.always
          else                             Interest.sometimes
          end
        end

        def next : Pointer(DefaultCallsite)
          Pointer(DefaultCallsite).new(@next_ptr.get(:acquire))
        end

        def next=(ptr : Pointer(DefaultCallsite))
          @next_ptr.set(ptr.address, :release)
        end
      end

      # Global callsite registry — linked list for DefaultCallsite,
      # mutex-guarded vector for trait-object callsites.
      class Callsites
        class_getter instance : Callsites = Callsites.new

        @head : Atomic(UInt64)
        @has_locked : Atomic(Bool)
        @locked : Array(Interface)
        @mutex : Mutex

        def initialize
          @head = Atomic(UInt64).new(0_u64)
          @has_locked = Atomic(Bool).new(false)
          @locked = [] of Interface
          @mutex = Mutex.new(:reentrant)
        end

        def push_default(callsite : DefaultCallsite) : Nil
          head_ptr = Pointer(DefaultCallsite).new(@head.get(:acquire))
          loop do
            callsite.next = head_ptr
            raise "Duplicate DefaultCallsite registration" if head_ptr && head_ptr == callsite
            if @head.compare_and_set(head_ptr.address, callsite.object_id, :acquire_release, :acquire)
              break
            end
            head_ptr = Pointer(DefaultCallsite).new(@head.get(:acquire))
          end
        end

        def push(callsite : Interface) : Nil
          @mutex.synchronize do
            @has_locked.set(true, :release)
            @locked << callsite
          end
        end

        def each(& : Interface ->) : Nil
          head_ptr = Pointer(DefaultCallsite).new(@head.get(:acquire))
          while head_ptr
            yield head_ptr.value
            head_ptr = head_ptr.value.next
          end

          if @has_locked.get(:acquire)
            @mutex.synchronize do
              @locked.each { |callsite| yield callsite }
            end
          end
        end
      end
    end
  end
end
