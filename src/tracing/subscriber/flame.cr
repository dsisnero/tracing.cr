module Tracing
  # A Layer that generates flamegraph data from span timings.
  #
  # Records span enter/exit events with microsecond precision and
  # writes folded stack format output consumable by `inferno`.
  #
  # Ported from upstream `tracing_flame::FlameLayer`.
  class FlameLayer < Layer
    @io : IO
    @out : IO
    @spans : Hash(Core::Span::Id, SpanInfo)
    @stack : Array(Core::Span::Id)
    @closed : Bool

    record SpanInfo, name : String, start_time : Time::Instant, parent_name : String?

    def initialize(@io : IO)
      @out = @io
      @spans = Hash(Core::Span::Id, SpanInfo).new
      @stack = [] of Core::Span::Id
      @closed = false
    end

    def self.with_file(path : String) : {FlameLayer, FlameGuard}
      file = File.open(path, mode: "w")
      layer = new(file)
      guard = FlameGuard.new(layer, file)
      {layer, guard}
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      parent_name = @stack.last?.try { |pid| @spans[pid]?.try(&.name) }
      @spans[id] = SpanInfo.new(attrs.metadata.name, Time.instant, parent_name)
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      @stack << id
      if info = @spans[id]?
        @spans[id] = SpanInfo.new(info.name, Time.instant, info.parent_name)
      end
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
      @stack.pop if @stack.last? == id
      return if @closed
      info = @spans[id]?
      return unless info

      elapsed = Time.instant - info.start_time
      write_folded(id, elapsed)
    end

    def close : Nil
      return if @closed
      @closed = true
      # Write remaining spans in stack
      @stack.reverse_each do |id|
        info = @spans[id]?
        next unless info
        elapsed = Time.instant - info.start_time
        write_folded(id, elapsed)
      end
      @stack.clear
    end

    private def write_folded(id : Core::Span::Id, elapsed : Time::Span) : Nil
      info = @spans[id]?
      return unless info

      # Build stack trace: parent;child;current
      parts = [] of String
      @stack.each do |sid|
        si = @spans[sid]?
        parts << si.name if si
      end

      # Also include the span being written if not on stack
      parts << info.name unless parts.last? == info.name

      return if parts.empty?

      @out << parts.join(";") << " " << elapsed.total_microseconds.to_i64 << "\n"
    end
  end

  # Ensures the FlameLayer is properly closed, flushing remaining spans.
  class FlameGuard
    @layer : FlameLayer
    @file : File

    def initialize(@layer : FlameLayer, @file : File)
    end

    def close : Nil
      @layer.close
      @file.close
    end

    def finalize
      close
    end
  end
end
