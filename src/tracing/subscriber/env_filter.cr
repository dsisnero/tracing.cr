module Tracing
  # A single filtering directive.
  struct Directive
    getter target : String?
    getter in_span : String?
    getter level : LevelFilter

    def initialize(@target, @in_span, @level)
    end

    def self.parse(s : String) : self
      s = s.strip
      return new(nil, nil, LevelFilter.error) if s.empty?

      target : String? = nil
      in_span : String? = nil
      level_str : String

      if idx = s.rindex('=')
        level_str = s[(idx + 1)..].strip
        target_str = s[...idx].strip

        unless target_str.empty?
          if bracket = target_str.rindex('[')
            if target_str.ends_with?(']')
              in_span = target_str[(bracket + 1)...-1].strip
              target = target_str[...bracket].strip
              target = nil if target.empty?
            else
              raise ArgumentError.new("unclosed bracket in directive: #{s}")
            end
          else
            target = target_str
          end
        end
      else
        level_str = s
      end

      level = LevelFilter.parse(level_str)
      new(target, in_span, level)
    end
  end

  # A filter that parses `RUST_LOG`-style environment variable strings
  # into filtering directives and applies them as a Layer.
  #
  # Ported from upstream `tracing_subscriber::filter::EnvFilter`.
  class EnvFilter < Layer
    getter directives : Array(Directive)

    def self.from_env(var : String = "TRACE_LOG") : self
      new(ENV[var]? || "")
    end

    def initialize(str : String = "")
      str = str.empty? ? (ENV["TRACE_LOG"]? || "error") : str
      @directives = str.split(',', remove_empty: true).map(&.strip).reject(&.empty?).map do |part|
        Directive.parse(part)
      end
      @directives = [Directive.parse("trace")] if @directives.empty?
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      @directives.any? { |d| directive_matches?(d, metadata, ctx) }
    end

    private def directive_matches?(d : Directive, meta : Metadata, ctx : LayerContext) : Bool
      if target = d.target
        return false unless meta.target.starts_with?(target)
      end
      if span_name = d.in_span
        if registry = ctx.subscriber.as?(Registry)
          current = registry.current_span_id
          return false unless current
          data = registry.span_data(current)
          return false unless data && data.name == span_name
        end
      end
      meta.level <= d.level
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
