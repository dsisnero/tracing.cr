module Tracing
  # A single filtering directive parsed from an EnvFilter string.
  #
  # Grammar: `target[span_name]=level`
  #
  # Ported from upstream `tracing_subscriber::filter::env::Directive`.
  struct Directive
    getter target : String?
    getter in_span : String?
    getter level : LevelFilter

    def initialize(@target, @in_span, @level)
    end

    # Parse a directive string.
    #
    # Examples:
    #   "info" → target=nil, in_span=nil, level=INFO
    #   "my_crate=debug" → target="my_crate", level=DEBUG
    #   "my_crate::mod=warn" → target="my_crate::mod", level=WARN
    #   "my_crate[my_span]=trace" → target="my_crate", in_span="my_span", level=TRACE
    #   "off" → OFF
    def self.parse(s : String) : self
      s = s.strip
      return new(nil, nil, LevelFilter.error) if s.empty?

      # Check for `=level` suffix
      target : String? = nil
      in_span : String? = nil
      level_str : String

      if idx = s.rindex('=')
        level_str = s[(idx + 1)..].strip
        target_str = s[...idx].strip

        if target_str.empty?
          target = nil
        else
          # Check for [span_name] suffix on target
          if bracket = target_str.rindex('[')
            if target_str.ends_with?(']')
              in_span = target_str[(bracket + 1)...-1].strip
              target = target_str[...bracket].strip
              target = nil if target.empty?
            else
              raise ArgumentError.new("unclosed bracket in directive: #{s}")
            end
          else
            target = target_str unless target_str.empty?
          end
        end
      else
        level_str = s
      end

      level = LevelFilter.parse(level_str)
      new(target, in_span, level)
    end
  end
end
