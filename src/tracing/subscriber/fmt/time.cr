module Tracing
  module FmtTime
    module FormatTime
      abstract def format_time(io : IO) : Nil
    end

    struct DateTime
      getter year : Int64
      getter month : UInt8
      getter day : UInt8
      getter hour : UInt8
      getter minute : UInt8
      getter second : UInt8
      getter micros : UInt32

      def initialize(@year : Int64, @month : UInt8, @day : UInt8, @hour : UInt8, @minute : UInt8, @second : UInt8, @micros : UInt32)
      end

      def self.from_unix(secs : Int64, nanos : UInt32) : DateTime
        t = secs
        raw_nanos = nanos

        leapoch = 946_684_800_i64 + 86_400_i64 * (31 + 29)
        days_per_400y = 365_i32 * 400 + 97
        days_per_100y = 365_i32 * 100 + 24
        days_per_4y = 365_i32 * 4 + 1
        days_in_month = StaticArray[31_i8, 30, 31, 30, 31, 31, 30, 31, 30, 31, 31, 29]

        days = (t // 86_400) - (leapoch // 86_400)
        remsecs = (t % 86_400).to_i32

        qc_cycles = (days // days_per_400y).to_i32
        remdays = (days % days_per_400y).to_i32

        c_cycles = remdays // days_per_100y
        c_cycles = 3 if c_cycles == 4
        remdays -= c_cycles * days_per_100y

        q_cycles = remdays // days_per_4y
        q_cycles = 24 if q_cycles == 25
        remdays -= q_cycles * days_per_4y

        remyears = remdays // 365
        remyears = 3 if remyears == 4
        remdays -= remyears * 365

        years = remyears.to_i64 + 4_i64 * q_cycles + 100_i64 * c_cycles + 400_i64 * qc_cycles

        months = 0_i32
        while days_in_month[months] <= remdays
          remdays -= days_in_month[months]
          months += 1
        end

        if months >= 10
          months -= 12
          years += 1
        end

        DateTime.new(
          year: years + 2000,
          month: (months + 3).to_u8,
          day: (remdays + 1).to_u8,
          hour: (remsecs // 3600).to_u8,
          minute: (remsecs // 60 % 60).to_u8,
          second: (remsecs % 60).to_u8,
          micros: raw_nanos // 1_000
        )
      end

      def to_s(io : IO) : Nil
        if @year > 9999
          io << '+' << @year
        elsif @year < 0
          io.printf("%05d", @year)
        else
          io.printf("%04d", @year)
        end

        io.printf("-%02d-%02dT%02d:%02d:%02d.%06dZ",
          @month, @day, @hour, @minute, @second, @micros)
      end

      def to_s : String
        String.build { |io| to_s(io) }
      end
    end

    struct SystemTime
      include FormatTime

      def format_time(io : IO) : Nil
        now = ::Time.utc
        DateTime.from_unix(secs: now.to_unix, nanos: now.nanosecond.to_u32).to_s(io)
      end
    end

    struct Uptime
      include FormatTime

      @epoch = ::Time.instant

      def format_time(io : IO) : Nil
        elapsed = ::Time.instant - @epoch
        total_nanos = elapsed.total_nanoseconds.to_i64
        secs = total_nanos // 1_000_000_000
        nanos = total_nanos % 1_000_000_000
        io.printf("%4d.%09ds", secs, nanos)
      end
    end

    def self.time : SystemTime
      SystemTime.new
    end

    def self.uptime : Uptime
      Uptime.new
    end
  end
end
