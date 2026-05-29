module Tracing
  # Controls which span lifecycle events the FmtLayer displays.
  # Ported from upstream `tracing_subscriber::fmt::format::FmtSpan`.
  @[Flags]
  enum FmtSpan : UInt8
    NONE   =       0
    NEW    =       1
    ENTER  =       2
    EXIT   =       4
    CLOSE  =       8
    ACTIVE =    6_u8 # ENTER | EXIT
    FULL   = 0xFF_u8
  end

  # A Layer that formats spans and events to an `IO` writer.
  #
  # Ported from upstream `tracing_subscriber::fmt`.
  class FmtLayer < Layer
    @io : IO
    @filter : LevelFilterLayer?
    @show_target : Bool
    @show_level : Bool
    @compact_mode : Bool
    @pretty_mode : Bool
    @span_events : FmtSpan
    @make_writer : (-> IO)?

    def initialize(io : IO = STDOUT, filter : LevelFilterLayer? = nil)
      @io = io
      @filter = filter
      @show_target = false
      @show_level = true
      @compact_mode = false
      @pretty_mode = false
      @span_events = FmtSpan::FULL
      @make_writer = nil
    end

    def compact : self
      @compact_mode = true
      @pretty_mode = false
      self
    end

    def pretty : self
      @pretty_mode = true
      @compact_mode = false
      self
    end

    def with_span_events(events : FmtSpan) : self
      @span_events = events
      self
    end

    def self.make_writer(&writer : -> IO) : self
      layer = new
      layer.writer_block = writer
      layer
    end

    def writer_block=(writer : (-> IO)?) : Nil
      @make_writer = writer
    end

    private def resolve_io : IO
      if writer = @make_writer
        writer.call
      else
        @io
      end
    end

    def with_filter(filter : LevelFilter) : self
      @filter = LevelFilterLayer.new(filter)
      self
    end

    def with_target(show : Bool) : self
      @show_target = show
      self
    end

    def with_level(show : Bool) : self
      @show_level = show
      self
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      if f = @filter
        f.enabled?(metadata, ctx)
      else
        true
      end
    end

    def max_level_hint : LevelFilter?
      @filter.try(&.max_level_hint)
    end

    def on_event(event : Core::Event, ctx : LayerContext) : Nil
      io = resolve_io
      span_name = ctx.event_span(event).try(&.name) || ""

      unless @compact_mode
        io << Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%LZ") << " "
      end
      if @show_level
        io << event.metadata.level.as_str.rjust(@compact_mode ? 0 : 5) << " "
      end
      if @show_target
        io << event.metadata.target << " "
      end
      unless span_name.empty?
        io << span_name << ":"
      end
      io << event.metadata.name

      if @pretty_mode
        io << ":\n"
      end

      vs = event.values
      if !vs.empty?
        if @pretty_mode
          collector = PrettyFieldCollector.new
          vs.visit(collector)
          collector.entries.each { |line| io << "  " << line << "\n" }
        else
          collector = FieldCollector.new
          vs.visit(collector)
          if collector.fields
            io << "{" << collector.fields << "}"
          end
        end
      end

      io << "\n" unless @pretty_mode
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      return unless @span_events.new?
      io = resolve_io
      io << Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%LZ") << " "
      io << attrs.metadata.level.as_str.rjust(5) << " "
      io << "new " << attrs.metadata.name << "\n"
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      return if @compact_mode
      return unless @span_events.enter?
      span = ctx.span(id)
      if span
        io = resolve_io
        io << Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%LZ") << " "
        io << span.metadata.level.as_str.rjust(5) << " "
        io << "enter " << span.name << "\n"
      end
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
      return if @compact_mode
      return unless @span_events.exit?
      span = ctx.span(id)
      if span
        io = resolve_io
        io << Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%LZ") << " "
        io << span.metadata.level.as_str.rjust(5) << " "
        io << "exit " << span.name << "\n"
      end
    end
  end

  private class FieldCollector
    include Core::Field::Visit
    property fields : String?

    def record_debug(field : Field::Field, value) : Nil
      append(field.name, value.to_s)
    end

    def record_i64(field : Field::Field, value : Int64) : Nil
      append(field.name, value.to_s)
    end

    def record_u64(field : Field::Field, value : UInt64) : Nil
      append(field.name, value.to_s)
    end

    def record_f64(field : Field::Field, value : Float64) : Nil
      append(field.name, value.to_s)
    end

    def record_bool(field : Field::Field, value : Bool) : Nil
      append(field.name, value.to_s)
    end

    def record_str(field : Field::Field, value : String) : Nil
      append(field.name, value)
    end

    def record_error(field : Field::Field, value : Exception) : Nil
      append(field.name, value.message || "")
    end

    private def append(key : String, val : String) : Nil
      pair = "#{key}=#{val}"
      if f = @fields
        @fields = f + " " + pair
      else
        @fields = pair
      end
    end
  end

  private class PrettyFieldCollector
    include Core::Field::Visit
    property entries : Array(String) = [] of String

    def record_debug(field : Field::Field, value) : Nil
      @entries << "  #{field.name}: #{value}"
    end

    def record_i64(field : Field::Field, value : Int64) : Nil
      @entries << "  #{field.name}: #{value}"
    end

    def record_u64(field : Field::Field, value : UInt64) : Nil
      @entries << "  #{field.name}: #{value}"
    end

    def record_f64(field : Field::Field, value : Float64) : Nil
      @entries << "  #{field.name}: #{value}"
    end

    def record_bool(field : Field::Field, value : Bool) : Nil
      @entries << "  #{field.name}: #{value}"
    end

    def record_str(field : Field::Field, value : String) : Nil
      @entries << "  #{field.name}: #{value}"
    end

    def record_error(field : Field::Field, value : Exception) : Nil
      @entries << "  #{field.name}: #{value.message || ""}"
    end
  end
end
