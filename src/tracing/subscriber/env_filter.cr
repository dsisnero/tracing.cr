module Tracing
  # A single field-name/value match condition in a directive.
  #
  # Ported from upstream `field::Match`.
  struct FieldMatch
    getter name : String
    getter value : String?

    def initialize(@name, @value = nil)
    end
  end

  # A single filtering directive.
  #
  # Ported from upstream `filter::env::Directive`.
  struct Directive
    getter target : String?
    getter in_span : String?
    getter fields : Array(FieldMatch)
    getter level : LevelFilter

    def initialize(@target, @in_span, @level, @fields = [] of FieldMatch)
    end

    def cares_about?(meta : Metadata) : Bool
      if target = @target
        return false unless meta.target.starts_with?(target)
      end
      if span_name = @in_span
        return false unless meta.name == span_name
      end
      @fields.each do |field|
        return false if meta.fields.field(field.name).nil?
      end
      true
    end

    # Parse a directive string of the form:
    #   `[target][[span_name[{field[=val],...}]]]=level`
    def self.parse(s : String) : self
      s = s.strip
      return new(nil, nil, LevelFilter.error) if s.empty?

      target : String? = nil
      in_span : String? = nil
      fields = [] of FieldMatch
      level_str : String

      if idx = s.rindex('=')
        level_str = s[(idx + 1)..].strip
        target_str = s[...idx].strip

        unless target_str.empty?
          if bracket = target_str.rindex('[')
            inner = target_str[(bracket + 1)..]
            if inner.ends_with?(']')
              inner = inner[...-1]
            else
              raise ArgumentError.new("unclosed bracket in directive: #{s}")
            end

            if brace_start = inner.index('{')
              if inner.ends_with?('}')
                span_part = inner[...brace_start].strip
                fields_part = inner[(brace_start + 1)...-1].strip
                in_span = span_part.empty? ? nil : span_part
                fields = parse_fields(fields_part)
              else
                raise ArgumentError.new("unclosed brace in directive: #{s}")
              end
            else
              in_span = inner.strip
              in_span = nil if in_span.empty?
            end

            target = target_str[...bracket].strip
            target = nil if target.empty?
          else
            target = target_str
          end
        end
      else
        level_str = s
      end

      level = LevelFilter.parse(level_str)
      new(target, in_span, level, fields)
    end

    private def self.parse_fields(s : String) : Array(FieldMatch)
      return [] of FieldMatch if s.empty?

      s.split(',', remove_empty: true).map do |part|
        part = part.strip
        if eq = part.index('=')
          FieldMatch.new(part[...eq].strip, part[(eq + 1)..].strip)
        else
          FieldMatch.new(part)
        end
      end
    end
  end

  # Visitor that collects field name/value pairs from a ValueSet.
  private class FieldCollector
    include Core::Field::Visit

    getter values : Hash(String, String)

    def initialize
      @values = {} of String => String
    end

    def record_debug(field : Core::Field::Field, value) : Nil
      @values[field.name] = value.to_s
    end

    def record_i64(field : Core::Field::Field, value : Int64) : Nil
      @values[field.name] = value.to_s
    end

    def record_u64(field : Core::Field::Field, value : UInt64) : Nil
      @values[field.name] = value.to_s
    end

    def record_f64(field : Core::Field::Field, value : Float64) : Nil
      @values[field.name] = value.to_s
    end

    def record_bool(field : Core::Field::Field, value : Bool) : Nil
      @values[field.name] = value.to_s
    end

    def record_str(field : Core::Field::Field, value : String) : Nil
      @values[field.name] = value
    end

    def record_error(field : Core::Field::Field, value : Exception) : Nil
      @values[field.name] = value.message || value.to_s
    end
  end

  # A filter that parses `RUST_LOG`-style environment variable strings
  # into filtering directives and applies them as a Layer.
  #
  # Ported from upstream `tracing_subscriber::filter::EnvFilter`.
  class EnvFilter < Layer
    getter directives : Array(Directive)
    @span_fields : Hash(UInt64, Hash(String, String))

    def self.from_env(var : String = "TRACE_LOG") : self
      new(ENV[var]? || "")
    end

    def initialize(str : String = "")
      str = str.empty? ? (ENV["TRACE_LOG"]? || "error") : str
      @directives = str.split(',', remove_empty: true).map(&.strip).reject(&.empty?).map do |part|
        Directive.parse(part)
      end
      @directives = [Directive.parse("trace")] if @directives.empty?
      @span_fields = {} of UInt64 => Hash(String, String)
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      collector = FieldCollector.new
      attrs.values.visit(collector)
      unless collector.values.empty?
        @span_fields[id.into_u64] = collector.values
      end
    end

    def on_record(id : Core::Span::Id, values : Core::Span::Record, ctx : LayerContext) : Nil
      collector = FieldCollector.new
      values.values.visit(collector)
      unless collector.values.empty?
        sid = id.into_u64
        @span_fields[sid] ||= {} of String => String
        @span_fields[sid].merge!(collector.values)
      end
    end

    def on_close(id : Core::Span::Id, ctx : LayerContext) : Nil
      @span_fields.delete(id.into_u64)
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      @directives.any? { |directive| directive_matches?(directive, metadata, ctx) }
    end

    private def directive_matches?(d : Directive, meta : Metadata, ctx : LayerContext) : Bool
      return false if d.target && !meta.target.starts_with?(d.target.not_nil!)
      span_id = current_span_id(ctx)
      return false if d.in_span && !span_matches?(d.in_span.not_nil!, span_id, ctx)
      return false if meta.event? && !event_fields_match?(d, span_id)
      meta.level <= d.level
    end

    private def span_matches?(name : String, span_id : Core::Span::Id?, ctx : LayerContext) : Bool
      return false unless span_id
      lookup = ctx.subscriber.as?(LookupSpan)
      return false unless lookup
      data = lookup.span_data(span_id)
      !!(data && data.name == name)
    end

    private def event_fields_match?(d : Directive, span_id : Core::Span::Id?) : Bool
      return true if d.fields.empty? || !span_id
      span_fields = @span_fields[span_id.into_u64]?
      return false unless span_fields
      d.fields.all? do |field_match|
        if value = field_match.value
          span_fields[field_match.name]? == value
        else
          span_fields.has_key?(field_match.name)
        end
      end
    end

    private def current_span_id(ctx : LayerContext) : Core::Span::Id?
      subscriber = ctx.subscriber.as?(LookupSpan)
      subscriber.try(&.current_span_id)
    end

    def max_level_hint : LevelFilter?
      @directives.map(&.level).reduce(nil) do |max, filter|
        if max
          filter > max ? filter : max
        else
          filter
        end
      end
    end

    private def directive_matches?(d : Directive, meta : Metadata) : Bool
      if target = d.target
        return false unless meta.target.starts_with?(target)
      end
      meta.level <= d.level
    end
  end
end
