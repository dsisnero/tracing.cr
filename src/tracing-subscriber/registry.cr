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

      def initialize(@id, @name, @metadata, @parent = nil)
        @ref_count = 1
      end
    end

    @spans : Hash(UInt64, SpanData)
    @mutex : Mutex
    @next_id : Atomic(UInt64)
    @max_level : LevelFilter?

    def initialize
      @spans = Hash(UInt64, SpanData).new
      @mutex = Mutex.new(:reentrant)
      @next_id = Atomic(UInt64).new(1_u64)
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

    def enter(id : Core::Span::Id) : Nil
    end

    def exit(id : Core::Span::Id) : Nil
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
  end
end
