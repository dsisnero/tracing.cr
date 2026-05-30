require "log"

module Tracing
  # A Log::Backend that forwards Crystal `Log` entries to `tracing` events.
  #
  # Supports all Log dispatch modes:
  # - :sync (default) — writes on calling fiber, uses fiber-local dispatch
  # - :async — writes on worker fiber, uses global default subscriber
  # - :direct — writes immediately on calling fiber
  #
  # Usage:
  #   # Default (sync): respects with_default scoping
  #   Log.setup(:trace, LogTracer.new)
  #
  #   # Async: uses global subscriber, non-blocking
  #   Log.setup(:trace, LogTracer.new(:async))
  #
  # Ported from upstream `tracing_log::LogTracer`.
  class LogTracer < ::Log::Backend
    @use_global : Bool

    def initialize(dispatch_mode : ::Log::DispatchMode = :sync)
      super(dispatch_mode: dispatch_mode)
      @use_global = (dispatch_mode != :sync && dispatch_mode != :direct)
    end

    def write(entry : ::Log::Entry) : Nil
      level = severity_to_level(entry.severity)
      dispatch = @use_global ? Dispatch.default : Dispatch.current
      return unless dispatch

      meta = Metadata.new(entry.message, entry.source, level, kind: Kind::EVENT)
      return unless dispatch.enabled(meta)

      event = Event.new(meta)
      dispatch.event(event)
    end

    def test_severity(severity : ::Log::Severity) : Level
      severity_to_level(severity)
    end

    private def severity_to_level(severity : ::Log::Severity) : Level
      case severity
      in .none?   then Level::ERROR
      in .trace?  then Level::TRACE
      in .debug?  then Level::DEBUG
      in .info?   then Level::INFO
      in .notice? then Level::INFO
      in .warn?   then Level::WARN
      in .error?  then Level::ERROR
      in .fatal?  then Level::ERROR
      end
    end
  end
end
