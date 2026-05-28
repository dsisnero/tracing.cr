module Tracing
  module Core
    # Describes the level of verbosity of a span or event.
    #
    # Levels which are more verbose are considered "greater than" levels
    # with ERROR as the lowest and TRACE as the highest.
    #
    # Numeric values are inverted (TRACE=0, ERROR=4) for optimized
    # integer comparisons. LevelFilter::OFF has a numeric value of 5.
    enum Level : UInt64
      TRACE = 0
      DEBUG = 1
      INFO  = 2
      WARN  = 3
      ERROR = 4

      def as_str : String
        case self
        in .trace? then "TRACE"
        in .debug? then "DEBUG"
        in .info?  then "INFO"
        in .warn?  then "WARN"
        in .error? then "ERROR"
        end
      end

      def to_s(io : IO) : Nil
        io << as_str
      end

      def self.parse(s : String) : self
        if num = s.to_u64?
          case num
          when 1 then return ERROR
          when 2 then return WARN
          when 3 then return INFO
          when 4 then return DEBUG
          when 5 then return TRACE
          end
        end
        case s.downcase
        when "error" then ERROR
        when "warn"  then WARN
        when "info"  then INFO
        when "debug" then DEBUG
        when "trace" then TRACE
        else              raise ParseLevelError.new
        end
      end

      # Inverted comparisons: TRACE(0) > DEBUG(1) > INFO(2) > WARN(3) > ERROR(4)

      def <(other : Level) : Bool
        other.value < value
      end

      def <=(other : Level) : Bool
        other.value <= value
      end

      def >(other : Level) : Bool
        other.value > value
      end

      def >=(other : Level) : Bool
        other.value >= value
      end

      def <=>(other : Level) : Int32
        other.value <=> value
      end
    end

    # A filter comparable to a verbosity Level.
    #
    # Internally represented as Level? where nil = OFF.
    # OFF has a numeric value of 5 (one more than ERROR's 4).
    struct LevelFilter
      OFF_U64 = 5_u64

      @level : Level?

      def self.off : self
        new(nil)
      end

      def self.error : self
        new(Level::ERROR)
      end

      def self.warn : self
        new(Level::WARN)
      end

      def self.info : self
        new(Level::INFO)
      end

      def self.debug : self
        new(Level::DEBUG)
      end

      def self.trace : self
        new(Level::TRACE)
      end

      def self.from_level(level : Level) : self
        new(level)
      end

      def initialize(@level : Level? = nil)
      end

      def into_level : Level?
        @level
      end

      protected def self.filter_to_u64(level : Level?) : UInt64
        case level
        in Level then level.value.to_u64
        in Nil   then OFF_U64
        end
      end

      def self.filter_to_u64(filter : self) : UInt64
        filter_to_u64(filter.@level)
      end

      def self.current : self
        val = @@max_level.get(:relaxed)
        case val
        when OFF_U64            then off
        when Level::ERROR.value then error
        when Level::WARN.value  then warn
        when Level::INFO.value  then info
        when Level::DEBUG.value then debug
        when Level::TRACE.value then trace
        else
          off
        end
      end

      def self.max=(filter : LevelFilter) : Nil
        @@max_level.set(filter_to_u64(filter), :acquire_release)
      end

      def to_s(io : IO) : Nil
        case @level
        in Level::TRACE then io << "trace"
        in Level::DEBUG then io << "debug"
        in Level::INFO  then io << "info"
        in Level::WARN  then io << "warn"
        in Level::ERROR then io << "error"
        in Nil          then io << "off"
        end
      end

      def inspect(io : IO) : Nil
        case @level
        in Level::TRACE then io << "LevelFilter::TRACE"
        in Level::DEBUG then io << "LevelFilter::DEBUG"
        in Level::INFO  then io << "LevelFilter::INFO"
        in Level::WARN  then io << "LevelFilter::WARN"
        in Level::ERROR then io << "LevelFilter::ERROR"
        in Nil          then io << "LevelFilter::OFF"
        end
      end

      # Upstream port parity: direct translation of Rust `FromStr for LevelFilter`,
      # which parses numeric strings (0-5) and named levels ("off", "error", ...).
      def self.parse(s : String) : self
        if num = s.to_u64?
          case num
          when 0 then return off
          when 1 then return error
          when 2 then return warn
          when 3 then return info
          when 4 then return debug
          when 5 then return trace
          end
        end
        if s.empty?
          return error
        end
        case s.downcase
        when "off"   then off
        when "error" then error
        when "warn"  then warn
        when "info"  then info
        when "debug" then debug
        when "trace" then trace
        else              raise ParseLevelFilterError.new
        end
      end

      # LevelFilter/Level comparisons (inverted)

      def <(other : Level) : Bool
        other.value < LevelFilter.filter_to_u64(@level)
      end

      def <=(other : Level) : Bool
        other.value <= LevelFilter.filter_to_u64(@level)
      end

      def >(other : Level) : Bool
        other.value > LevelFilter.filter_to_u64(@level)
      end

      def >=(other : Level) : Bool
        other.value >= LevelFilter.filter_to_u64(@level)
      end

      def ==(other : Level) : Bool
        LevelFilter.filter_to_u64(@level) == other.value
      end

      def <=>(other : LevelFilter) : Int32
        LevelFilter.filter_to_u64(other) <=> LevelFilter.filter_to_u64(@level)
      end

      def ==(other : LevelFilter) : Bool
        @level == other.@level
      end

      def hash(hasher)
        @level.hash(hasher)
      end

      @@max_level : Atomic(UInt64) = Atomic.new(OFF_U64)
    end

    # Error when parsing an invalid Level string.
    class ParseLevelError < ArgumentError
      MESSAGE = %(error parsing level: expected one of "error", "warn", "info", "debug", "trace", or a number 1-5)

      def initialize
        super(MESSAGE)
      end
    end

    # Error when parsing an invalid LevelFilter string.
    class ParseLevelFilterError < ArgumentError
      MESSAGE = %(error parsing level filter: expected one of "off", "error", "warn", "info", "debug", "trace", or a number 0-5)

      def initialize
        super(MESSAGE)
      end
    end

    module Callsite
      # An opaque identifier for a callsite.
      struct Identifier
        getter ptr : Pointer(Void)

        def initialize(@ptr : Pointer(Void) = Pointer(Void).null)
        end

        def ==(other : Identifier) : Bool
          @ptr == other.@ptr
        end

        def to_s(io : IO) : Nil
          io << "0x#{@ptr.address.to_s(16)}"
        end
      end

      # Indicates the subscriber's interest in a callsite.
      enum Interest : UInt8
        NEVER     = 0
        SOMETIMES = 1
        ALWAYS    = 2

        def self.never : self
          NEVER
        end

        def self.sometimes : self
          SOMETIMES
        end

        def self.always : self
          ALWAYS
        end

        def never? : Bool
          self == NEVER
        end

        def always? : Bool
          self == ALWAYS
        end

        # Combine two interests: returns the most restrictive (lowest) interest.
        def and(other : Interest) : Interest
          value <= other.value ? self : other
        end
      end
    end

    # Indicates whether a callsite is a span, event, or hint.
    struct Kind
      EVENT_BIT = 1_u8
      SPAN_BIT  = 2_u8
      HINT_BIT  = 4_u8

      EVENT = new(EVENT_BIT)
      SPAN  = new(SPAN_BIT)
      HINT  = new(HINT_BIT)

      getter bits : UInt8

      def initialize(@bits : UInt8 = 0)
      end

      def event? : Bool
        @bits & EVENT_BIT == EVENT_BIT
      end

      def span? : Bool
        @bits & SPAN_BIT == SPAN_BIT
      end

      def hint? : Bool
        @bits & HINT_BIT == HINT_BIT
      end

      def hint : self
        Kind.new(@bits | HINT_BIT)
      end

      def ==(other : Kind) : Bool
        @bits == other.@bits
      end

      def to_s(io : IO) : Nil
        io << "Kind("
        has_bits = false
        if event?
          io << "EVENT"
          has_bits = true
        end
        if span?
          io << " | " if has_bits
          io << "SPAN"
          has_bits = true
        end
        if hint?
          io << " | " if has_bits
          io << "HINT"
          has_bits = true
        end
        io << ")" unless has_bits
        io << ")"
      end
    end
  end
end
