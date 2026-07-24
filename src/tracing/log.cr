require "log"

module Tracing
  module Log
    VERSION = "0.2.0"

    # Convert a tracing Level to a ::Log Severity.
    # Ported from upstream `AsLog for Level`.
    def self.level_as_log(level : Level) : ::Log::Severity
      case level
      in .error? then ::Log::Severity::Error
      in .warn?  then ::Log::Severity::Warn
      in .info?  then ::Log::Severity::Info
      in .debug? then ::Log::Severity::Debug
      in .trace? then ::Log::Severity::Trace
      end
    end

    # Convert a tracing LevelFilter to a ::Log Severity.
    # Ported from upstream `AsLog for LevelFilter`.
    def self.level_filter_as_log(filter : LevelFilter) : ::Log::Severity
      case filter.into_level
      in Level::ERROR then ::Log::Severity::Error
      in Level::WARN  then ::Log::Severity::Warn
      in Level::INFO  then ::Log::Severity::Info
      in Level::DEBUG then ::Log::Severity::Debug
      in Level::TRACE then ::Log::Severity::Trace
      in Nil          then ::Log::Severity::None
      end
    end

    # Convert a ::Log Severity to a tracing Level.
    # Ported from upstream `AsTrace for log::Level`.
    def self.severity_as_trace(severity : ::Log::Severity) : Level
      case severity
      in .trace?  then Level::TRACE
      in .debug?  then Level::DEBUG
      in .info?   then Level::INFO
      in .notice? then Level::INFO
      in .warn?   then Level::WARN
      in .error?  then Level::ERROR
      in .fatal?  then Level::ERROR
      in .none?   then Level::ERROR
      end
    end
  end
end
