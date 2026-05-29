module Tracing
  # A Layer that formats spans and events to an `IO` writer.
  #
  # Ported from upstream `tracing_subscriber::fmt`.
  class FmtLayer < Layer
    @io : IO
    @filter : LevelFilterLayer?

    def initialize(@io : IO = STDOUT, @filter : LevelFilterLayer? = nil)
    end

    def with_filter(filter : LevelFilter) : self
      @filter = LevelFilterLayer.new(filter)
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
      span_name = ctx.event_span(event).try(&.name) || ""
      span_info = span_name.empty? ? "" : " #{span_name}:"

      @io << Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%LZ") << " "
      @io << event.metadata.level.as_str.rjust(5) << " "
      @io << span_info << event.metadata.name

      # Record fields in key=value format
      vs = event.values
      if !vs.empty?
        collector = FieldCollector.new
        vs.visit(collector)
        if collector.fields
          @io << "{" << collector.fields << "}"
        end
      end

      @io << "\n"
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      @io << Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%LZ") << " "
      @io << attrs.metadata.level.as_str.rjust(5) << " "
      @io << "new " << attrs.metadata.name << "\n"
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
      span = ctx.span(id)
      if span
        @io << Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%LZ") << " "
        @io << span.metadata.level.as_str.rjust(5) << " "
        @io << "enter " << span.name << "\n"
      end
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
      span = ctx.span(id)
      if span
        @io << Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%LZ") << " "
        @io << span.metadata.level.as_str.rjust(5) << " "
        @io << "exit " << span.name << "\n"
      end
    end
  end

  # Collects field key=value pairs for display.
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
end
