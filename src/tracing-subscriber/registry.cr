module Tracing
  # A Registry is a Subscriber that stores span data and exposes it
  # for lookup by Layers.
  #
  # Ported from upstream `tracing_subscriber::registry::Registry`.
  class Registry
    include Core::Subscriber

    # Stored data for a single span.
    struct SpanData
      getter id : Core::Span::Id
      getter name : String
      getter metadata : Metadata
      getter parent : Core::Span::Id?
      property ref_count : Int32
      getter extensions : Extensions

      def initialize(@id, @name, @metadata, @parent = nil)
        @ref_count = 1
        @extensions = Extensions.new
      end
    end

    @spans : Hash(UInt64, SpanData)
    @mutex : Mutex
    @next_id : Atomic(UInt64)
    @max_level : LevelFilter?
    @current_span_ids : Hash(UInt64, Array(Core::Span::Id)) # fiber-local current spans

    def initialize
      @spans = Hash(UInt64, SpanData).new
      @mutex = Mutex.new(:reentrant)
      @next_id = Atomic(UInt64).new(1_u64)
      @current_span_ids = Hash(UInt64, Array(Core::Span::Id)).new
    end

    # Get the current span for the current fiber.
    def current_span : Core::Span::Id?
      @current_span_ids[Fiber.current.object_id]?.try(&.last?)
    end

    # ---- Subscriber implementation ----

    def enter(id : Core::Span::Id) : Nil
      fiber_id = Fiber.current.object_id
      @mutex.synchronize do
        @current_span_ids[fiber_id] ||= [] of Core::Span::Id
        @current_span_ids[fiber_id] << id
      end
    end

    def exit(id : Core::Span::Id) : Nil
      fiber_id = Fiber.current.object_id
      @mutex.synchronize do
        if stack = @current_span_ids[fiber_id]?
          stack.pop
        end
      end
    end

    # Lookup span data by ID.
    def span_data(id : Core::Span::Id) : SpanData?
      @mutex.synchronize { @spans[id.into_u64]? }
    end

    # ---- Subscriber implementation ----

    def new_span(attrs : Core::Span::Attributes) : Core::Span::Id
      idx = @next_id.add(1, :relaxed)
      id = Core::Span::Id.from_u64(idx)
      data = SpanData.new(id, attrs.metadata.name, attrs.metadata, parent: attrs.parent.id)
      @mutex.synchronize { @spans[id.into_u64] = data }
      id
    end

    def event(event : Core::Event) : Nil
    end

    def record(id : Core::Span::Id, values : Core::Span::Record) : Nil
    end

    def record_follows_from(span : Core::Span::Id, follows : Core::Span::Id) : Nil
    end

    def enabled(metadata : Metadata) : Bool
      @max_level.try { |max| metadata.level <= max } || true
    end

    def register_callsite(metadata : Metadata) : Callsite::Interest
      Callsite::Interest.always
    end

    def max_level_hint : LevelFilter?
      @max_level
    end

    def self.default : self
      new
    end

    # Set this registry (with its layers) as the global default subscriber.
    def init : Nil
      Tracing::Subscriber.set_global_default(self)
    end
  end
end
