require "json"
require "./fmt/writer"

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
    @json_mode : Bool
    @span_events : FmtSpan
    @make_writer_block : (-> IO)?
    @make_writer_obj : FmtWriter::MakeWriter?
    @use_ansi : Bool
    @timer : FmtTime::FormatTime?
    @show_thread_ids : Bool
    @show_thread_names : Bool
    @json_flatten_event : Bool
    @json_show_current_span : Bool
    @json_show_span_list : Bool
    @field_formatter : FmtFormat::FormatFields

    def initialize(io : IO = STDOUT, filter : LevelFilterLayer? = nil)
      @io = io
      @filter = filter
      @show_target = false
      @show_level = true
      @compact_mode = false
      @pretty_mode = false
      @json_mode = false
      @span_events = FmtSpan::FULL
      @make_writer_block = nil
      @make_writer_obj = nil
      @use_ansi = false
      @timer = FmtTime.time
      @show_thread_ids = false
      @show_thread_names = false
      @json_flatten_event = false
      @json_show_current_span = true
      @json_show_span_list = true
      @field_formatter = FmtFormat::DefaultFields.new
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

    def json : self
      @json_mode = true
      @compact_mode = false
      @pretty_mode = false
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

    def self.with_test_writer : self
      layer = new
      layer.writer_block = -> { FmtWriter::TestWriter.new.as(IO) }
      layer
    end

    def writer_block=(writer : (-> IO)?) : Nil
      @make_writer_block = writer
    end

    def with_make_writer(mw : FmtWriter::MakeWriter) : self
      @make_writer_obj = mw
      self
    end

    private def write_json_event(io : IO, event : Core::Event, ctx : LayerContext) : Nil
      span_name = (@json_show_current_span ? ctx.event_span(event).try(&.name) : nil)
      vs = event.values

      obj = {} of String => JSON::Any
      if ts = timestamp_str
        obj["timestamp"] = JSON::Any.new(ts)
      end
      obj["level"] = JSON::Any.new(event.metadata.level.as_str)

      if @json_flatten_event
        obj["name"] = JSON::Any.new(event.metadata.name)
        collector = JsonFieldCollector.new
        vs.visit(collector)
        collector.entries.each do |key, any_val|
          obj[key] = any_val
        end
      end

      if span_name
        obj["span"] = JSON::Any.new(span_name)
      end

      unless @json_flatten_event
        fields = {} of String => JSON::Any
        fields["message"] = JSON::Any.new(event.metadata.name)
        collector = JsonFieldCollector.new
        vs.visit(collector)
        collector.entries.each do |key, any_val|
          fields[key] = any_val
        end
        obj["fields"] = JSON::Any.new(fields)
      end

      if @show_target
        obj["target"] = JSON::Any.new(event.metadata.target)
      end

      if @show_thread_names
        if name = Fiber.current.name
          obj["threadName"] = JSON::Any.new(name)
        elsif !@show_thread_ids
          obj["threadName"] = JSON::Any.new(Fiber.current.object_id.to_s)
        end
      end
      if @show_thread_ids
        obj["threadId"] = JSON::Any.new(Fiber.current.object_id.to_s)
      end

      obj.to_json(io)
      io << "\n"
    end

    private def resolve_io(meta : Metadata? = nil) : IO
      if mw = @make_writer_obj
        mw.make_writer(meta)
      elsif writer = @make_writer_block
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

    def with_ansi(use : Bool) : self
      @use_ansi = use
      self
    end

    # Display the current thread's identifier. In Crystal, threads map to
    # fibers, so this shows the fiber's object id (see Divergences).
    def with_thread_ids(show : Bool) : self
      @show_thread_ids = show
      self
    end

    # Display the current thread's name. In Crystal, threads map to fibers, so
    # this shows the fiber's name (see Divergences).
    def with_thread_names(show : Bool) : self
      @show_thread_names = show
      self
    end

    def flatten_event(flatten : Bool) : self
      @json_flatten_event = flatten
      self
    end

    def with_current_span(show : Bool) : self
      @json_show_current_span = show
      self
    end

    def with_span_list(show : Bool) : self
      @json_show_span_list = show
      self
    end

    def with_timer(timer : FmtTime::FormatTime?) : self
      @timer = timer
      self
    end

    def with_test_writer : self
      @make_writer_block = -> { FmtWriter::TestWriter.new.as(IO) }
      self
    end

    def with_none_timer : self
      @timer = nil
      self
    end

    def without_time : self
      with_none_timer
    end

    private def write_timestamp(io : IO) : Nil
      if t = @timer
        t.format_time(io)
        io << " "
      end
    end

    # Writes the fiber name and/or id after the level, mirroring upstream's
    # thread name/id display: the name is shown if present, falling back to the
    # id when the name is absent and ids are not separately enabled.
    private def write_thread_info(io : IO) : Nil
      if @show_thread_names
        if name = Fiber.current.name
          io << name << " "
        elsif !@show_thread_ids
          io << Fiber.current.object_id << " "
        end
      end
      if @show_thread_ids
        io << Fiber.current.object_id << " "
      end
    end

    private def timestamp_str : String?
      t = @timer
      return unless t
      String.build { |io| t.format_time(io) }
    end

    private def level_color(level : Level) : String
      return "" unless @use_ansi
      case level
      in .error? then "\e[31m"
      in .warn?  then "\e[33m"
      in .info?  then "\e[32m"
      in .debug? then "\e[34m"
      in .trace? then "\e[36m"
      end
    end

    private def reset_color : String
      @use_ansi ? "\e[0m" : ""
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
      io = resolve_io(event.metadata)

      if @json_mode
        write_json_event(io, event, ctx)
        return
      end
      span_name = ctx.event_span(event).try(&.name) || ""

      unless @compact_mode
        write_timestamp(io)
      end
      if @show_level
        color = level_color(event.metadata.level)
        reset = reset_color
        io << color << event.metadata.level.as_str.rjust(@compact_mode ? 0 : 5) << reset << " "
      end
      write_thread_info(io)
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
          io << "{"
          fwriter = FmtFormat::Writer.new(io)
          @field_formatter.format_fields(fwriter, vs)
          io << "}"
        end
      end

      io << "\n" unless @pretty_mode
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      return unless @span_events.new?
      io = resolve_io
      write_timestamp(io)
      io << attrs.metadata.level.as_str.rjust(5) << " "
      io << "new " << attrs.metadata.name << "\n"
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      return if @compact_mode
      return unless @span_events.enter?
      span = ctx.span(id)
      if span
        io = resolve_io
        write_timestamp(io)
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
        write_timestamp(io)
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

  private class JsonFieldCollector
    include Core::Field::Visit
    property entries : Hash(String, JSON::Any) = {} of String => JSON::Any

    def record_debug(field : Field::Field, value) : Nil
      @entries[field.name] = JSON::Any.new(value.to_s)
    end

    def record_i64(field : Field::Field, value : Int64) : Nil
      @entries[field.name] = JSON::Any.new(value)
    end

    def record_u64(field : Field::Field, value : UInt64) : Nil
      @entries[field.name] = JSON::Any.new(value)
    end

    def record_f64(field : Field::Field, value : Float64) : Nil
      @entries[field.name] = JSON::Any.new(value)
    end

    def record_bool(field : Field::Field, value : Bool) : Nil
      @entries[field.name] = JSON::Any.new(value)
    end

    def record_str(field : Field::Field, value : String) : Nil
      @entries[field.name] = JSON::Any.new(value)
    end

    def record_error(field : Field::Field, value : Exception) : Nil
      @entries[field.name] = JSON::Any.new(value.message || "")
    end
  end
end
