require "./fiber"

class Fiber
  def self.spawn_traced(name : String? = nil, level = Tracing::Level::INFO, **span_fields, &block : -> T) : FiberWithResult(T) forall T
    dispatch = Tracing::Dispatch.current
    done = Channel(T).new

    spawn do
      if d = dispatch
        Tracing::Dispatch.with_default(d) do
          s = Tracing.span(level, name || "fiber", **span_fields)
          result = s.in_scope { block.call }
          done.send(result)
        end
      else
        result = block.call
        done.send(result)
      end
    end

    FiberWithResult(T).new(done)
  end
end

class FiberWithResult(T)
  @channel : Channel(T)

  def initialize(@channel : Channel(T))
  end

  def await : T
    @channel.receive
  end
end
