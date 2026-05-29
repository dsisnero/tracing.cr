require "opentelemetry-api"

module Tracing
  # A tracing Layer that converts spans and events to OpenTelemetry.
  #
  # Ported from upstream `tracing_opentelemetry::OpenTelemetryLayer`.
  class OpenTelemetryLayer < Layer
    getter tracer

    def initialize(@tracer = nil)
    end

    def self.kind_from_field(name : String?) : OpenTelemetry::API::Span::Kind
      case name
      when "server"   then OpenTelemetry::API::Span::Kind::Server
      when "client"   then OpenTelemetry::API::Span::Kind::Client
      when "producer" then OpenTelemetry::API::Span::Kind::Producer
      when "consumer" then OpenTelemetry::API::Span::Kind::Consumer
      when "internal" then OpenTelemetry::API::Span::Kind::Internal
      else                 OpenTelemetry::API::Span::Kind::Internal
      end
    end

    def self.status_from_code(code : String?) : OpenTelemetry::API::Status
      status = OpenTelemetry::API::Status.new
      status.code = case code
                    when "Ok"    then OpenTelemetry::API::AbstractStatus::StatusCode::Ok
                    when "Error" then OpenTelemetry::API::AbstractStatus::StatusCode::Error
                    else              OpenTelemetry::API::AbstractStatus::StatusCode::Unset
                    end
      status
    end

    def on_new_span(attrs : Core::Span::Attributes, id : Core::Span::Id, ctx : LayerContext) : Nil
      otel_span = @tracer.try(&.start_span(attrs.metadata.name))
      return unless span_ref = ctx.span(id)
      return unless exts = span_ref.extensions_mut

      data = OtelSpanData.new(attrs.metadata.name)
      data.otel_span = otel_span
      exts.insert(data)
    end

    def on_enter(id : Core::Span::Id, ctx : LayerContext) : Nil
    end

    def on_exit(id : Core::Span::Id, ctx : LayerContext) : Nil
    end

    def on_event(event : Core::Event, ctx : LayerContext) : Nil
    end

    def error_event?(meta : Metadata) : Bool
      meta.level == Level::ERROR
    end

    def exception_attributes(message : String, stacktrace : String) : Hash(String, String)
      {
        "exception.message"    => message,
        "exception.stacktrace" => stacktrace,
      }
    end
  end

  struct OtelSpanData
    getter name : String
    property otel_span

    def initialize(@name : String)
    end
  end
end
