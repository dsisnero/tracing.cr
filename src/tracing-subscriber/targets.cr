module Tracing
  # A programmatic filter that matches events by target (module) prefix.
  #
  # Ported from upstream `tracing_subscriber::filter::Targets`.
  class Targets < Layer
    record Rule, target : String, level : LevelFilter

    @rules : Array(Rule)
    @default_level : LevelFilter

    def initialize
      @rules = [] of Rule
      @default_level = LevelFilter.trace
    end

    def with_target(target : String, level : Level) : self
      @rules << Rule.new(target, LevelFilter.from_level(level))
      self
    end

    def with_default(level : LevelFilter) : self
      @default_level = level
      self
    end

    def default_level : LevelFilter
      @default_level
    end

    # Parse target=level pairs from environment variable.
    #
    # Format: "target=level,target2=level,default=level"
    #
    # Ported from upstream `tracing_subscriber::filter::Targets::from_env`.
    def self.from_env(var : String = "TRACE_TARGETS") : self
      targets = new
      if raw = ENV[var]?
        raw.split(',').each do |part|
          part = part.strip
          next if part.empty?
          if pair = part.split('=', 2)
            key = pair[0].strip
            val = pair[1]?.try(&.strip)
            next unless val
            if key == "default"
              targets.with_default(LevelFilter.parse(val))
            else
              targets.with_target(key, Level.parse(val))
            end
          end
        end
      end
      targets
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      level = matching_level(metadata.target)
      metadata.level <= level
    end

    def max_level_hint : LevelFilter?
      @rules.map(&.level).reduce(@default_level) do |max, level|
        level > max ? level : max
      end
    end

    private def matching_level(target : String) : LevelFilter
      @rules.each do |rule|
        return rule.level if target.starts_with?(rule.target)
      end
      @default_level
    end
  end
end
