require "log"

module Tracing
  # A Log::Backend that forwards Crystal `Log` entries to `tracing` events.
  #
  # Uses the globally configured tracing subscriber (Dispatch.default).
  # Set up the tracing subscriber first, then configure Log:
  #
  #   Registry.default.with(FmtLayer.new(STDOUT)).init
  #   Log.setup(:trace, LogTracer.new)
  #
  # Ported from upstream `tracing_log::LogTracer`.
  class LogTracer < ::Log::Backend
    def initialize
      super(dispatch_mode: :sync)
    end

    def write(entry : ::Log::Entry) : Nil
      level = severity_to_level(entry.severity)
      dispatch = Dispatch.default
      return unless dispatch

      meta = Metadata.new(entry.message, entry.source, level, kind: Kind::EVENT)
      return unless dispatch.enabled(meta)

      event = Event.new(meta)
      dispatch.event(event)
    end

    # Test helper: expose severity mapping
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
