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
  #   # With builder:
  #   LogTracer.builder
  #     .with_max_level(Level::INFO)
  #     .ignore_crate("some_crate")
  #     .finish
  #
  # Ported from upstream `tracing_log::LogTracer`.
  class LogTracer < ::Log::Backend
    @use_global : Bool
    @ignore_crates : Array(String)
    @max_level : LevelFilter

    def initialize(dispatch_mode : ::Log::DispatchMode = :sync,
                   ignore_crates : Array(String) = [] of String,
                   max_level : LevelFilter = LevelFilter.trace)
      super(dispatch_mode: dispatch_mode)
      @use_global = (dispatch_mode != :sync && dispatch_mode != :direct)
      @ignore_crates = ignore_crates
      @max_level = max_level
    end

    def self.builder : LogTracerBuilder
      LogTracerBuilder.new
    end

    def write(entry : ::Log::Entry) : Nil
      level = severity_to_level(entry.severity)
      return if level > @max_level

      if @ignore_crates.any? { |ignored| entry.source.starts_with?(ignored) }
        return
      end

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

  # Builder for configuring a LogTracer.
  #
  # Ported from upstream `tracing_log::Builder`.
  class LogTracerBuilder
    @ignore_crates : Array(String)
    @max_level : LevelFilter

    def initialize
      @ignore_crates = [] of String
      @max_level = LevelFilter.trace
    end

    def with_max_level(level : Level) : self
      @max_level = LevelFilter.from_level(level)
      self
    end

    def with_max_level(filter : LevelFilter) : self
      @max_level = filter
      self
    end

    def ignore_crate(name : String) : self
      @ignore_crates << name
      self
    end

    def ignore_all(crates : Enumerable(String)) : self
      @ignore_crates.concat(crates)
      self
    end

    def finish : LogTracer
      LogTracer.new(
        dispatch_mode: :sync,
        ignore_crates: @ignore_crates.dup,
        max_level: @max_level
      )
    end
  end
end
