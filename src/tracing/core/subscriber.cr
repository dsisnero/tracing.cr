module Tracing
  module Core
    # The trait implemented to collect trace data.
    module Subscriber
      abstract def new_span(attrs : Span::Attributes) : Span::Id
      abstract def enter(id : Span::Id) : Nil
      abstract def exit(id : Span::Id) : Nil
      abstract def event(event : Event) : Nil
      abstract def record(id : Span::Id, values : Span::Record) : Nil
      abstract def record_follows_from(span : Span::Id, follows : Span::Id) : Nil
      abstract def enabled(metadata : Metadata) : Bool
      abstract def register_callsite(metadata : Metadata) : Callsite::Interest

      def max_level_hint : LevelFilter?
        nil
      end

      def current_span : Span::Current
        Span::Current.unknown
      end

      def clone_span(id : Span::Id) : Span::Id
        id
      end

      def drop_span(id : Span::Id) : Nil
      end

      def try_close(id : Span::Id) : Bool
        false
      end
    end

    class NoSubscriber
      include Subscriber

      def new_span(attrs : Span::Attributes) : Span::Id
        Span::Id.from_u64(1)
      end

      def enter(id : Span::Id) : Nil
      end

      def exit(id : Span::Id) : Nil
      end

      def event(event : Event) : Nil
      end

      def record(id : Span::Id, values : Span::Record) : Nil
      end

      def record_follows_from(span : Span::Id, follows : Span::Id) : Nil
      end

      def enabled(metadata : Metadata) : Bool
        false
      end

      def register_callsite(metadata : Metadata) : Callsite::Interest
        Callsite::Interest.sometimes
      end
    end
  end
end
