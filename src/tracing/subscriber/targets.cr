module Tracing
  # A programmatic filter that matches events by target (module) prefix.
  #
  # Ported from upstream `tracing_subscriber::filter::Targets`.
  class Targets < Layer
    # A single target/level directive. A `nil` target is the default directive,
    # applied to spans and events whose target matched no other directive.
    record Directive, target : String?, level : LevelFilter do
      def cares_about_target?(to_check : String) : Bool
        if t = target
          to_check.starts_with?(t)
        else
          true
        end
      end
    end

    @directives : Array(Directive)

    def initialize
      @directives = [] of Directive
    end

    # Parses a comma-delimited list of `target=level` directives.
    #
    # Each directive is one of:
    #   * `target=level`  (e.g. `my_crate::module=info`)
    #   * `target`        (bare target, enabled at `TRACE`)
    #   * `level`         (bare level, sets the default level)
    #
    # Levels are case-insensitive names (`off`, `error`, `warn`, `info`,
    # `debug`, `trace`) or numbers `0`-`5`. Mirrors upstream `FromStr`.
    def self.parse(s : String) : Targets
      targets = new
      s.split(',').each do |segment|
        target, level = parse_directive(segment)
        targets.add_directive(target, level)
      end
      targets
    end

    private def self.parse_directive(segment : String) : {String?, LevelFilter}
      parts = segment.split('=')
      if parts.size > 2
        raise ArgumentError.new("too many '=' in filter directive, expected 0 or 1")
      end

      if parts.size == 2
        {parts[0], LevelFilter.parse(parts[1])}
      else
        # No `=`: a bare level sets the default, otherwise a bare target at TRACE.
        begin
          {nil, LevelFilter.parse(parts[0])}
        rescue ParseLevelFilterError
          {parts[0], LevelFilter.trace}
        end
      end
    end

    def with_target(target : String, level : Level) : self
      add_directive(target, LevelFilter.from_level(level))
      self
    end

    def with_target(target : String, level : LevelFilter) : self
      add_directive(target, level)
      self
    end

    def with_targets(pairs : Enumerable({String, Level}) | Enumerable({String, LevelFilter})) : self
      pairs.each do |target, level|
        case level
        in Level       then with_target(target, level)
        in LevelFilter then with_target(target, level)
        end
      end
      self
    end

    def with_targets(pairs : Enumerable({String, (Level | LevelFilter)})) : self
      pairs.each do |target, level|
        case level
        in Level       then with_target(target, level)
        in LevelFilter then with_target(target, level)
        end
      end
      self
    end

    def with_default(level : LevelFilter) : self
      add_directive(nil, level)
      self
    end

    # Returns the default level, or `nil` if no default has been set. An unset
    # default behaves like `LevelFilter::OFF` when filtering.
    def default_level : LevelFilter?
      @directives.each do |directive|
        return directive.level if directive.target.nil?
      end
      nil
    end

    # Returns a lazy iterator over the target/level pairs in this filter,
    # excluding the default. Mirrors upstream `Targets::iter`, which returns an
    # `Iterator`.
    def iter : Iterator({String, LevelFilter})
      @directives.each.compact_map do |directive|
        if t = directive.target
          {t, directive.level}
        end
      end
    end

    # Returns whether a target/level pair would be enabled by this filter.
    def would_enable(target : String, level : Level) : Bool
      @directives.each do |directive|
        return level <= directive.level if directive.cares_about_target?(target)
      end
      false
    end

    def enabled?(metadata : Metadata, ctx : LayerContext) : Bool
      would_enable(metadata.target, metadata.level)
    end

    def max_level_hint : LevelFilter?
      @directives.map(&.level).reduce(LevelFilter.off) do |max, level|
        level > max ? level : max
      end
    end

    def to_s(io : IO) : Nil
      first = true
      @directives.each do |directive|
        io << ',' unless first
        first = false
        if t = directive.target
          io << t << '='
        end
        directive.level.to_s(io)
      end
    end

    def ==(other : Targets) : Bool
      directives == other.directives
    end

    def hash(hasher)
      @directives.hash(hasher)
    end

    # Adds or replaces the directive for `target` (`nil` = default), then keeps
    # `@directives` ordered most-specific-first so the longest matching prefix
    # wins and the default directive is always tried last. Mirrors upstream
    # `StaticDirective::Ord` (reversed so the set is searched most-specific
    # first); replacing on duplicate target matches the upstream "last wins"
    # behavior of `with_default`.
    protected def add_directive(target : String?, level : LevelFilter) : Nil
      @directives.reject! { |directive| directive.target == target }
      @directives << Directive.new(target, level)
      @directives.sort! do |a, b|
        la = a.target.try(&.size) || -1
        lb = b.target.try(&.size) || -1
        if la == lb
          (b.target || "") <=> (a.target || "")
        else
          lb <=> la
        end
      end
    end

    protected def directives : Array(Directive)
      @directives
    end
  end
end
