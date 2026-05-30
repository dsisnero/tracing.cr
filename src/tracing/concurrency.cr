require "../tracing"

module Tracing::Concurrency
  # Spawn a fiber that inherits the current span context.
  #
  # Ported from upstream `tracing-futures::Instrument::in_current_span`.
  def self.spawn(name : String? = nil, level = Tracing::Level::INFO, **span_fields, &block : -> T) : Channel(T) forall T
    dispatch = Dispatch.current
    done = Channel(T).new

    ::spawn do
      if d = dispatch
        Dispatch.with_default(d) do
          s = Tracing.span(level, name || "fiber", **span_fields)
          result = s.in_scope { block.call }
          done.send(result)
        end
      else
        result = block.call
        done.send(result)
      end
    end

    done
  end

  # Spawn a fiber that runs inside the given span.
  #
  # Ported from upstream `tracing-futures::Instrument::instrument`.
  def self.spawn_with_span(span : Span, &block : -> T) : Channel(T) forall T
    dispatch = Dispatch.current
    done = Channel(T).new

    ::spawn do
      if d = dispatch
        Dispatch.with_default(d) do
          result = span.in_scope { block.call }
          done.send(result)
        end
      else
        result = span.in_scope { block.call }
        done.send(result)
      end
    end

    done
  end
end
