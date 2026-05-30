# Fiber span propagation.
#
# Ported from upstream `tracing-futures::Instrument` trait.
module Tracing::Concurrency
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

  def self.with_subscriber(subscriber : Core::Subscriber, &block : -> T) : Channel(T) forall T
    done = Channel(T).new
    dispatch = Dispatch.new(subscriber)

    ::spawn do
      Dispatch.with_default(dispatch) do
        result = block.call
        done.send(result)
      end
    end

    done
  end
end
