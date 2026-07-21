module Tracing
  enum TraceStyle
    Threaded
    Async
  end

  # Wraps an Event or SpanRef for name/category function callbacks.
  class EventOrSpan
    getter event : Core::Event?
    getter span_ref : SpanRef?

    def initialize(@event : Core::Event)
    end

    def initialize(@span_ref : SpanRef)
    end

    def event? : Bool
      !@event.nil?
    end

    def span? : Bool
      !@span_ref.nil?
    end

    def metadata : Metadata
      if e = @event
        e.metadata
      else
        @span_ref.not_nil!.metadata
      end
    end
  end

  # Internal cached data for a trace event callsite.
  struct CallsiteInfo
    getter tid : UInt64
    getter name : String
    getter target : String
    getter file : String?
    getter line : UInt32?
    getter args : Hash(String, JSON::Any)?

    def initialize(@tid : UInt64, @name : String, @target : String, @file : String?, @line : UInt32?, @args : Hash(String, JSON::Any)? = nil)
    end
  end

  # Internal message types for the writer channel.
  abstract class Message
  end

  class EnterMessage < Message
    getter ts : Float64
    getter callsite : CallsiteInfo
    getter root_id : UInt64?

    def initialize(@ts : Float64, @callsite : CallsiteInfo, @root_id : UInt64? = nil)
    end
  end

  class ExitMessage < Message
    getter ts : Float64
    getter callsite : CallsiteInfo
    getter root_id : UInt64?

    def initialize(@ts : Float64, @callsite : CallsiteInfo, @root_id : UInt64? = nil)
    end
  end

  class EventMessage < Message
    getter ts : Float64
    getter callsite : CallsiteInfo

    def initialize(@ts : Float64, @callsite : CallsiteInfo)
    end
  end

  class NewThreadMessage < Message
    getter tid : UInt64
    getter name : String

    def initialize(@tid : UInt64, @name : String)
    end
  end

  class FlushMessage < Message
  end

  class DropMessage < Message
  end

  class StartNewMessage < Message
    getter writer : IO?

    def initialize(@writer : IO? = nil)
    end
  end

  # Visitor that records field values into a JSON-compatible hash.
  class JsonVisitor
    include Core::Field::Visit

    getter object : Hash(String, JSON::Any)

    def initialize
      @object = Hash(String, JSON::Any).new
    end

    def record_debug(field : Core::Field::Field, value) : Nil
      @object[field.name] = JSON::Any.new(value.to_s)
    end

    def record_i64(field : Core::Field::Field, value : Int64) : Nil
      @object[field.name] = JSON::Any.new(value)
    end

    def record_u64(field : Core::Field::Field, value : UInt64) : Nil
      @object[field.name] = JSON::Any.new(value.to_i64)
    end

    def record_f64(field : Core::Field::Field, value : Float64) : Nil
      @object[field.name] = JSON::Any.new(value)
    end

    def record_bool(field : Core::Field::Field, value : Bool) : Nil
      @object[field.name] = JSON::Any.new(value)
    end

    def record_str(field : Core::Field::Field, value : String) : Nil
      @object[field.name] = JSON::Any.new(value)
    end

    def record_error(field : Core::Field::Field, value : Exception) : Nil
      @object[field.name] = JSON::Any.new(value.message || value.class.name)
    end
  end

  # Wrapper for span extensions to cache recorded arguments.
  struct ArgsWrapper
    getter args : Hash(String, JSON::Any)

    def initialize(@args : Hash(String, JSON::Any))
    end
  end

  def self.create_default_writer : IO
    File.new("./trace-#{Time.utc.to_unix_ms}.json", "w")
  end

  # A Layer that writes Chrome trace format JSON.
  class ChromeLayer < Layer
    @out : Channel(Message)
    @start : Time::Instant
    @next_tid : UInt64
    @tid_mutex : Mutex
    @tid_map : Hash(UInt64, UInt64)
    @include_args : Bool
    @include_locations : Bool
    @trace_style : TraceStyle
    @name_fn : Proc(EventOrSpan, String)?
    @cat_fn : Proc(EventOrSpan, String)?

    def initialize(builder : ChromeLayerBuilder, @out : Channel(Message))
      @start = Time.instant
      @include_args = builder.include_args?
      @include_locations = builder.include_locations?
      @trace_style = builder.trace_style
      @name_fn = builder.name_fn
      @cat_fn = builder.cat_fn
      @next_tid = 0_u64
      @tid_mutex = Mutex.new
      @tid_map = Hash(UInt64, UInt64).new
    end

    def ts : Float64
      (Time.instant - @start).total_nanoseconds / 1000.0
    end

    def tid : {UInt64, Bool}
      fiber_id = Fiber.current.object_id
      @tid_mutex.synchronize do
        if existing = @tid_map[fiber_id]?
          {existing, false}
        else
          tid = @next_tid
          @next_tid += 1
          @tid_map[fiber_id] = tid
          {tid, true}
        end
      end
    end

    def get_callsite(data : EventOrSpan) : CallsiteInfo
      tid, new_thread = tid
      meta = data.metadata
      name = @name_fn.try(&.call(data)) || meta.name
      target = @cat_fn.try(&.call(data)) || meta.target
      file = @include_locations ? meta.file : nil
      line = @include_locations ? meta.line : nil
      args = extract_args(data)

      if new_thread
        thread_name = Fiber.current.name || tid.to_s
        send_message(NewThreadMessage.new(tid, thread_name))
      end

      CallsiteInfo.new(tid, name, target, file, line, args)
    end

    private def extract_args(data : EventOrSpan) : Hash(String, JSON::Any)?
      return unless @include_args

      if data.event?
        visitor = JsonVisitor.new
        data.event.not_nil!.record(visitor)
        visitor.object
      elsif data.span?
        data.span_ref.not_nil!.extensions.try(&.get(ArgsWrapper)).try(&.args)
      end
    end

    def get_root_id(span : SpanRef) : UInt64
      span.scope.from_root.first?.try(&.id.into_u64) || span.id.into_u64
    end

    def send_message(message : Message) : Nil
      @out.send(message)
    end

    # ---- Layer trait implementation ----

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      return if @trace_style.async?
      timestamp = ts
      if span = ctx.span(id)
        enter_span(span, timestamp)
      end
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
      return if @trace_style.async?
      timestamp = ts
      if span = ctx.span(id)
        exit_span(span, timestamp)
      end
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      if @include_args
        if span = ctx.span(id)
          visitor = JsonVisitor.new
          attrs.values.visit(visitor)
          span.extensions_mut.try(&.insert(ArgsWrapper.new(visitor.object)))
        end
      end
      return if @trace_style.threaded?
      timestamp = ts
      if span = ctx.span(id)
        enter_span(span, timestamp)
      end
    end

    def on_close(id : Core::Span::Id, ctx : LayerContext) : Nil
      return if @trace_style.threaded?
      timestamp = ts
      if span = ctx.span(id)
        exit_span(span, timestamp)
      end
    end

    def on_event(event : Core::Event, ctx : LayerContext) : Nil
      timestamp = ts
      callsite = get_callsite(EventOrSpan.new(event))
      send_message(EventMessage.new(timestamp, callsite))
    end

    def on_record(id : Core::Span::Id, values : Core::Span::Record, ctx : LayerContext) : Nil
      return unless @include_args
      return unless span = ctx.span(id)
      return unless ext = span.extensions_mut
      return unless wrapper = ext.get(ArgsWrapper)
      visitor = JsonVisitor.new
      visitor.object.merge!(wrapper.args)
      values.values.visit(visitor)
      ext.replace(ArgsWrapper.new(visitor.object))
    end

    private def enter_span(span : SpanRef, ts : Float64) : Nil
      callsite = get_callsite(EventOrSpan.new(span))
      root_id = @trace_style.async? ? get_root_id(span) : nil
      send_message(EnterMessage.new(ts, callsite, root_id))
    end

    private def exit_span(span : SpanRef, ts : Float64) : Nil
      callsite = get_callsite(EventOrSpan.new(span))
      root_id = @trace_style.async? ? get_root_id(span) : nil
      send_message(ExitMessage.new(ts, callsite, root_id))
    end
  end

  # Builder for ChromeLayer.
  class ChromeLayerBuilder
    getter out_writer : IO?
    getter name_fn : Proc(EventOrSpan, String)?
    getter cat_fn : Proc(EventOrSpan, String)?
    getter? include_args : Bool
    getter? include_locations : Bool
    getter trace_style : TraceStyle

    def initialize
      @out_writer = nil
      @name_fn = nil
      @cat_fn = nil
      @include_args = false
      @include_locations = true
      @trace_style = TraceStyle::Threaded
    end

    def file(path : String) : self
      writer(File.new(path, "w"))
    end

    def writer(io : IO) : self
      @out_writer = io
      self
    end

    def include_args(arg : Bool) : self
      @include_args = arg
      self
    end

    def include_locations(arg : Bool) : self
      @include_locations = arg
      self
    end

    def trace_style(style : TraceStyle) : self
      @trace_style = style
      self
    end

    def name_fn(fn : Proc(EventOrSpan, String)) : self
      @name_fn = fn
      self
    end

    def category_fn(fn : Proc(EventOrSpan, String)) : self
      @cat_fn = fn
      self
    end

    def build : {ChromeLayer, FlushGuard}
      channel = Channel(Message).new
      done = Channel(Nil).new
      initial_out = @out_writer || Tracing.create_default_writer

      spawn do
        current_out = initial_out
        write = current_out
        write << "[\n"
        has_started = false
        thread_names = [] of {UInt64, String}

        loop do
          msg = channel.receive

          if msg.is_a?(FlushMessage)
            write.flush
            next
          elsif msg.is_a?(DropMessage)
            break
          elsif msg.is_a?(StartNewMessage)
            write << "\n]"
            write.flush
            current_out = msg.writer || Tracing.create_default_writer
            write = current_out
            write << "[\n"
            has_started = false
            thread_names.each do |tid, name|
              entry = build_metadata_entry(tid, name)
              write << ",\n" if has_started
              write << entry
              has_started = true
            end
            next
          end

          entry = build_trace_entry(msg)
          write << ",\n" if has_started
          write << entry
          has_started = true
        end

        write << "\n]"
        write.flush
        done.send(nil)
      end

      layer = ChromeLayer.new(self, channel)
      guard = FlushGuard.new(channel, done)
      {layer, guard}
    end

    private def build_trace_entry(msg : Message) : String
      if msg.is_a?(EnterMessage)
        build_enter_entry(msg)
      elsif msg.is_a?(ExitMessage)
        build_exit_entry(msg)
      elsif msg.is_a?(EventMessage)
        build_event_entry(msg)
      elsif msg.is_a?(NewThreadMessage)
        build_metadata_entry(msg.tid, msg.name)
      else
        "{}"
      end
    end

    private def build_enter_entry(msg : EnterMessage) : String
      JSON.build do |json|
        json.object do
          ph = msg.root_id.nil? ? "B" : "b"
          json.field "ph", ph
          json.field "pid", 1
          json.field "ts", msg.ts
          json.field "name", msg.callsite.name
          json.field "cat", msg.callsite.target
          json.field "tid", msg.callsite.tid.to_i64
          if id = msg.root_id
            json.field "id", id.to_i64
          end
          add_location(json, msg.callsite)
          add_args(json, msg.callsite)
        end
      end
    end

    private def build_exit_entry(msg : ExitMessage) : String
      JSON.build do |json|
        json.object do
          ph = msg.root_id.nil? ? "E" : "e"
          json.field "ph", ph
          json.field "pid", 1
          json.field "ts", msg.ts
          json.field "name", msg.callsite.name
          json.field "cat", msg.callsite.target
          json.field "tid", msg.callsite.tid.to_i64
          if id = msg.root_id
            json.field "id", id.to_i64
          end
          add_location(json, msg.callsite)
          add_args(json, msg.callsite)
        end
      end
    end

    private def build_event_entry(msg : EventMessage) : String
      JSON.build do |json|
        json.object do
          json.field "ph", "i"
          json.field "pid", 1
          json.field "ts", msg.ts
          json.field "name", msg.callsite.name
          json.field "cat", msg.callsite.target
          json.field "tid", msg.callsite.tid.to_i64
          json.field "s", "t"
          add_location(json, msg.callsite)
          add_args(json, msg.callsite)
        end
      end
    end

    private def build_metadata_entry(tid : UInt64, name : String) : String
      JSON.build do |json|
        json.object do
          json.field "ph", "M"
          json.field "pid", 1
          json.field "name", "thread_name"
          json.field "tid", tid.to_i64
          json.field "args" do
            json.object do
              json.field "name", name
            end
          end
        end
      end
    end

    private def add_location(json : JSON::Builder, callsite : CallsiteInfo) : Nil
      if file = callsite.file
        json.field ".file", file
      end
      if line = callsite.line
        json.field ".line", line
      end
    end

    private def add_args(json : JSON::Builder, callsite : CallsiteInfo) : Nil
      if args = callsite.args
        unless args.empty?
          json.field "args" do
            json.object do
              args.each do |key, value|
                json.field key, value
              end
            end
          end
        end
      end
    end
  end

  # Guard that signals the writer to flush or stop on drop.
  class FlushGuard
    @sender : Channel(Message)
    @done : Channel(Nil)

    def initialize(@sender : Channel(Message), @done : Channel(Nil))
    end

    def flush : Nil
      @sender.send(FlushMessage.new)
    end

    def start_new(writer : IO? = nil) : Nil
      @sender.send(StartNewMessage.new(writer))
    end

    def finalize
      @sender.send(DropMessage.new)
      @done.receive
    end
  end
end
