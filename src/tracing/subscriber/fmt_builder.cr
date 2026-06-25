module Tracing
  DEFAULT_MAX_LEVEL = LevelFilter.info

  class FmtSubscriberBuilder
    @layer : FmtLayer
    @filter : LevelFilter
    @filter_layer : Layer?

    def initialize
      @layer = FmtLayer.new
      @filter = DEFAULT_MAX_LEVEL
      @filter_layer = nil
    end

    def finish : Layered(Layered(Registry))
      inner = Registry.new.with(@layer)
      filter_l = @filter_layer || LevelFilterLayer.new(@filter)
      inner.with(filter_l)
    end

    def init : Nil
      Subscriber.set_global_default(finish)
    end

    def try_init : Bool
      init
      true
    rescue
      false
    end

    def with_writer(io : IO) : self
      @layer.writer_block = -> { io.as(IO) }
      self
    end

    def with_target(show : Bool) : self
      @layer.with_target(show)
      self
    end

    def with_level(show : Bool) : self
      @layer.with_level(show)
      self
    end

    def without_time : self
      @layer.without_time
      self
    end

    def with_timer(timer : FmtTime::FormatTime?) : self
      @layer.with_timer(timer)
      self
    end

    def with_ansi(use : Bool) : self
      @layer.with_ansi(use)
      self
    end

    def with_span_events(events : FmtSpan) : self
      @layer.with_span_events(events)
      self
    end

    def compact : self
      @layer.compact
      self
    end

    def pretty : self
      @layer.pretty
      self
    end

    def json : self
      @layer.json
      self
    end

    def with_thread_ids(show : Bool) : self
      @layer.with_thread_ids(show)
      self
    end

    def with_thread_names(show : Bool) : self
      @layer.with_thread_names(show)
      self
    end

    def flatten_event(flatten : Bool) : self
      @layer.flatten_event(flatten)
      self
    end

    def with_current_span(show : Bool) : self
      @layer.with_current_span(show)
      self
    end

    def with_span_list(show : Bool) : self
      @layer.with_span_list(show)
      self
    end

    def with_max_level(filter : LevelFilter) : self
      @filter = filter
      self
    end

    def with_filter_reloading : self
      filter_l = LevelFilterLayer.new(@filter)
      reload_layer, @reload_handle = Reload.new(filter_l)
      @filter_layer = reload_layer
      self
    end

    def reload_handle : Handle
      @reload_handle.not_nil!
    end

    @reload_handle : Handle?
  end
end
