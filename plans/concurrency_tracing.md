# Concurrency Tracing Plan

Crystal equivalents of Rust's `tracing-futures` for Crystal's concurrency
primitives: `Fiber`, `Channel`, `ExecutionContext`.

Upstream: `vendor/tracing/tracing-futures/src/lib.rs` (785 lines)
Reference: `vendor/perf-tools/` — already instruments Fiber spawning/yielding

## Upstream Pattern (Rust)

`tracing-futures` provides two key abstractions:

### 1. Instrument (attach span to async work)

```rust
pub trait Instrument: Sized {
    fn instrument(self, span: Span) -> Instrumented<Self>;
    fn in_current_span(self) -> Instrumented<Self>;
}
```

`Instrumented<T>` wraps a `Future<T>`. On each `poll`, it enters the attached
span, runs the inner future, then exits the span. This ensures span context
propagates across await points.

### 2. WithSubscriber (attach subscriber context)

```rust
pub trait WithSubscriber: Sized {
    fn with_subscriber<S>(self, subscriber: S) -> WithDispatch<Self>;
    fn with_current_subscriber(self) -> WithDispatch<Self>;
}
```

`WithDispatch<T>` wraps a `Future<T>`. On each `poll`, it sets the attached
subscriber as the thread-local default, then restores the prior subscriber
after polling. This ensures the subscriber context propagates across threads.

## Crystal Equivalents

Crystal has no `Future`/`Poll` model. Concurrency is fiber-based:

| Rust | Crystal | Instrumentation strategy |
|------|---------|-------------------------|
| `Future::poll` | `Fiber` resume/yield | Enter span on fiber resume, exit on yield |
| `tokio::spawn` | `spawn` | Propagate current span to spawned fiber |
| `tokio::channel` | `Channel(T)` | Trace send/receive as span events |
| `tokio::select` | `select` | Trace branch selection |
| Thread-local dispatch | Fiber-local dispatch | Already done (`Dispatch.with_default`) |
| `tokio::Runtime` | `ExecutionContext` | Trace work scheduling across contexts |

## What Perf-Tools Already Does

`vendor/perf-tools/src/perf_tools/fiber_trace.cr` monkey-patches `Fiber` to:

```crystal
class Fiber
  @__spawn_stack : Array(Void*)?  # creation stack trace
  @__yield_stack : Array(Void*)?  # last yield stack trace
end
```

It wraps `Fiber.new` to capture the spawn call stack, and patches
`Crystal::Scheduler#resume` to capture the yield call stack. This is
_stack tracing_, not _span tracing_ — it records raw call stacks, not
structured tracing spans.

`vendor/perf-tools/src/core_ext/fiber.cr` adds fiber name tracking.

## What We Need

For Crystal concurrency tracing, we need these layers:

### 1. Fiber Span Propagation (`src/tracing/subscriber/fiber_instrument.cr`)

When a fiber is spawned, propagate the current tracing span so the new fiber
continues in the same span context.

```crystal
# Proposed API:
class Tracing::InstrumentedFiber
  def initialize(@span : Span, @fiber : Fiber)
  end

  def self.spawn(name = nil, **span_fields, &block : -> T) : Fiber forall T
    span = Span.current || span!(Level::INFO, name || "fiber", **span_fields)
    fiber = Fiber.new(name) { span.in_scope { yield } }
    fiber
  end
end

# Usage:
Tracing::InstrumentedFiber.spawn("worker", queue: "emails") do
  info!("processing")
end
```

### 2. Channel Tracing (`src/tracing/subscriber/channel_trace.cr`)

Trace `Channel#send` and `Channel#receive` as span events.

```crystal
# Proposed API:
class Tracing::TracedChannel(T)
  def initialize(@channel : Channel(T), @name : String)
  end

  def send(value : T)
    span!(Level::TRACE, "channel.send", channel: @name) do |s|
      @channel.send(value)
      s.record(value: value)
    end
  end

  def receive : T
    span!(Level::TRACE, "channel.receive", channel: @name).in_scope do
      @channel.receive
    end
  end
end
```

### 3. ExecutionContext Tracing (`src/tracing/subscriber/execution_context_trace.cr`)

Crystal 1.20+ introduces `ExecutionContext` classes:
- `ExecutionContext::SingleThreaded`
- `ExecutionContext::MultiThreaded`
- `ExecutionContext::Concurrent`
- `ExecutionContext::Isolated`
- `ExecutionContext::Parallel`

When work moves between execution contexts, trace the context switch as
a span boundary.

```crystal
# Proposed: wrap ExecutionContext to emit span events on work dispatch
class Tracing::InstrumentedExecutionContext
  def self.wrap(ctx : ExecutionContext)
    # patch to emit trace events when fibers are scheduled
  end
end
```

## Implementation Order

### Phase 1: Fiber Span Propagation (low effort, high value)

- [ ] `Tracing::InstrumentedFiber.spawn` — span-aware fiber creation
- [ ] `Fiber#with_span(span)` — attach span to existing fiber
- [ ] `Span.current_fiber` — get span attached to current fiber
- [ ] `Dispatch.with_default` already handles fiber-local dispatch

**Ports from upstream**: `Instrument::in_current_span` pattern

### Phase 2: Channel Tracing (medium effort)

- [ ] `Tracing::TracedChannel(T)` — wrap send/receive in span events
- [ ] `Tracing::TracedSelect` — trace multi-channel select
- [ ] `Channel(T)#traced` extension — convert to traced channel

**Ports from upstream**: N/A (no direct equivalent in `tracing-futures`)

### Phase 3: ExecutionContext Tracing (high effort)

- [ ] `ExecutionContext` monkey-patch for fiber scheduling trace
- [ ] `tracing_subscriber::ExecutionContextLayer` — subscriber that records context switches
- [ ] Integration with `perf-tools` `SchedulerTrace` for runtime status

**Ports from upstream**: `WithDispatch` pattern (propagate subscriber across context)

## Dependencies

| Dependency | Purpose | Status |
|-----------|---------|--------|
| `perf-tools` | Reference implementation for Fiber monkey-patching | Vendored at `vendor/perf-tools/` |
| `tracing-futures` (Rust) | Source of truth for async instrumentation patterns | `vendor/tracing/tracing-futures/` |

## Notes

- Crystal fibers are cooperative, not preemptive. `Fiber.yield` is explicit.
  Instrumentation points are: spawn, resume, yield, and explicit Channel ops.
- `perf-tools` already demonstrates the monkey-patching approach needed for
  Fiber/Scheduler instrumentation.
- Phase 1 (Fiber Span Propagation) is the clear next step — it's low effort
  and directly parallels Rust's `Instrument` trait.
