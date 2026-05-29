module Tracing
  # A subscriber for testing that records events and spans.
  #
  # Supports basic expectations via `expect_event_named` and
  # `assert_finished` for verification.
  #
  # Ported from upstream `tracing_mock::subscriber::MockSubscriber`.
  class MockSubscriber
    include Core::Subscriber

    getter events : Array(Core::Event) = [] of Core::Event
    getter spans : Array(Tuple(Core::Span::Attributes, Core::Span::Id)) = [] of Tuple(Core::Span::Attributes, Core::Span::Id)
    getter enters : Array(Core::Span::Id) = [] of Core::Span::Id
    getter exits : Array(Core::Span::Id) = [] of Core::Span::Id
    @expected_event_names : Array(String) = [] of String
    @next_id : UInt64 = 1_u64

    def new_span(attrs : Core::Span::Attributes) : Core::Span::Id
      id = Core::Span::Id.from_u64(@next_id)
      @next_id += 1
      @spans << {attrs, id}
      id
    end

    def enter(id : Core::Span::Id) : Nil
      @enters << id
    end

    def exit(id : Core::Span::Id) : Nil
      @exits << id
    end

    def event(event : Core::Event) : Nil
      @events << event
      @expected_event_names.shift if @expected_event_names.includes?(event.metadata.name)
    end

    def record(id : Core::Span::Id, values : Core::Span::Record) : Nil
    end

    def record_follows_from(span : Core::Span::Id, follows : Core::Span::Id) : Nil
    end

    def enabled(metadata : Metadata) : Bool
      true
    end

    def register_callsite(metadata : Metadata) : Callsite::Interest
      Callsite::Interest.always
    end

    def expect_event_named(name : String) : self
      @expected_event_names << name
      self
    end

    def assert_finished : Nil
      remaining = @expected_event_names.dup
      @events.each { |e| remaining.delete(e.metadata.name) }
      unless remaining.empty?
        raise "mock subscriber: expected events not emitted: #{remaining.join(", ")}"
      end
    end
  end
end
