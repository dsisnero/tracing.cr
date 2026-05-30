# tracing

A Crystal port of [tokio-rs/tracing](https://github.com/tokio-rs/tracing) — structured,
event-based diagnostics for Crystal programs.

**Upstream pinned at**: `tracing-0.1.44` (commit `2d55f6f`)

## Documentation

| Document | Purpose |
|----------|---------|
| [Architecture](docs/architecture.md) | Crate structure, data flow, file map |
| [Development](docs/development.md) | Setup, daily workflow, commands |
| [Coding Guidelines](docs/coding-guidelines.md) | Code style and conventions |
| [Testing](docs/testing.md) | Test commands and patterns |
| [PR Workflow](docs/pr-workflow.md) | Commits, PRs, review process |

## Installation

```yaml
dependencies:
  tracing:
    github: dsisnero/tracing.cr
```

```bash
shards install
```

## Quick Start

```crystal
require "tracing"

# Set up a subscriber with formatted output
Tracing::Subscriber.set_global_default(
  Tracing::Registry.default
    .with(Tracing::FmtLayer.new(STDOUT).compact)
)

# Record spans and events
span = span!(Level::INFO, "my_operation", service: "api")
span.in_scope do
  info!("processing", user_id: 42)
end
```

## Core Concepts

### Spans

A span represents a period of time with a beginning and end.
See `src/tracing/facade_span.cr` for the `Tracing::Span` handle.

```crystal
# Create a span with initial fields
span = span!(Level::INFO, "request", method: "GET")

# Enter the span (auto-exits via ensure block)
span.in_scope do
  # Work happens inside the span context
  span.record(progress: "50%")
end
```

### Events

An event represents a moment in time within a span context.
See `src/tracing/facade_dsl.cr` for the DSL methods.

```crystal
# Outside any span
info!("server_started", port: 8080)

# Inside a span
span!(Level::DEBUG, "db_query").in_scope do
  debug!("query_executed", rows: 100, duration_ms: 12)
end
```

### Levels

Verbosity ordered from most to least verbose:
`TRACE > DEBUG > INFO > WARN > ERROR`

```crystal
Level::TRACE > Level::DEBUG   # => true
Level::ERROR < Level::WARN    # => true
```

LevelFilter adds `OFF` to completely disable:
```crystal
LevelFilter::OFF < Level::TRACE  # => true (OFF blocks everything)
```

See `src/tracing/types.cr` for the full comparison semantics.

### Subscribers

Subscribers consume trace data. Register one to start recording.
See `src/tracing/subscriber.cr` for the trait.

```crystal
# Built-in Registry with a formatting layer
Tracing::Subscriber.set_global_default(
  Tracing::Registry.default
    .with(Tracing::FmtLayer.new(STDOUT)
      .with_target(true)
      .with_ansi(true)
      .compact)
    .with(Tracing::EnvFilter.from_env)
)
```

## FmtLayer Output

Three output modes via `src/tracing-subscriber/fmt.cr`:

**Default** (timestamped single-line):
```
2026-05-28T22:00:00.000Z  INFO my_span:request{method=GET}
```

**Compact** (`.compact`, no timestamps):
```
INFO request{method=GET}
```

**Pretty** (`.pretty`, multi-line):
```
2026-05-28T22:00:00.000Z  INFO request:
  method: GET
  path: /users
```

## Filtering

Four filter types from `src/tracing-subscriber/`:

```crystal
# Level threshold
FmtLayer.new.with_filter(LevelFilter::INFO)

# Environment variable parsing
EnvFilter.new("info,my_crate=debug,http=trace")
EnvFilter.from_env  # reads $TRACE_LOG

# Closure-based
FilterFn.new { |meta| meta.level <= Level::WARN }

# Programmatic target matching
Targets.new
  .with_target("my_crate", Level::DEBUG)
  .with_target("http", Level::TRACE)
  .with_default(Level::INFO)
```

**Directive grammar** (`EnvFilter`):
```
info                         # bare level
my_crate=debug               # target prefix + level
my_crate::module=warn        # scoped target
my_crate[span_name]=trace    # span-filtered
off                          # disable all
```

## Layers

Layers observe trace data. Compose with `Registry.with(layer)`.
See `src/tracing-subscriber/layer.cr`.

```crystal
class MetricsLayer < Tracing::Layer
  def on_event(event, ctx)
    # record metrics
  end

  def on_new_span(attrs, id, ctx)
    # track span creation
  end
end

Registry.default
  .with(MetricsLayer.new)
  .with(FmtLayer.new(STDOUT).compact)
  .init
```

### Layer Composition

```crystal
# Chain layers
registry.with(security_layer).with(fmt_layer)

# Combine layers with filtering
fmt_layer.and_then(LevelFilterLayer.new(LevelFilter::INFO))

# Conditional layers (nil is a no-op)
debug ? debug_layer : nil
```

## Span Data Lookup

Layers can query stored span data via the context.
See `src/tracing-subscriber/lookup_span.cr`.

```crystal
class SpanLogger < Tracing::Layer
  def on_event(event, ctx)
    if span = ctx.event_span(event)
      puts "Event in span: #{span.name}"
      if data = span.extensions
        puts "  user: #{data.get(String)}"
      end
    end
  end
end
```

## Per-Span Extensions

Store arbitrary per-span data via `src/tracing-subscriber/extensions.cr`:

```crystal
class TimingLayer < Tracing::Layer
  def on_new_span(attrs, id, ctx)
    if span = ctx.span(id)
      span.extensions_mut.try(&.insert(Time.utc))
    end
  end

  def on_exit(id, ctx)
    if span = ctx.span(id)
      start = span.extensions.try(&.get(Time))
      elapsed = Time.utc - start if start
    end
  end
end
```

## Dynamic Writers

Enable file rotation via `make_writer` block in `src/tracing-subscriber/fmt.cr`:

```crystal
FmtLayer.make_writer { File.open("app.log", "a") }
```

## JSON Output

Output events as JSON lines via `src/tracing-subscriber/fmt.cr`:

```crystal
FmtLayer.new(STDOUT).json
# => {"timestamp":"2026-...","level":"INFO","name":"request","user":"alice"}
```

## OpenTelemetry

Bridge tracing spans to OpenTelemetry via `src/tracing-opentelemetry/layer.cr`:

```crystal
require "opentelemetry-api"
require "opentelemetry-sdk"

OpenTelemetry.configure do |config|
  config.service_name = "my_app"
end

tracer = OpenTelemetry.tracer_provider.tracer("my_app")

Registry.default
  .with(OpenTelemetryLayer.new(tracer)
    .with_level(Level::INFO))
  .init
```

OTel fields on spans:
- `otel.name` — dynamic span name
- `otel.kind` — server/client/producer/consumer/internal
- `otel.status_code` — Ok/Error
- `otel.status_description` — status detail

## Crystal Log Bridge

Forward Crystal `Log` entries to tracing events via `src/tracing-subscriber/log_tracer.cr`:

```crystal
Registry.default.with(FmtLayer.new(STDOUT)).init
Log.setup(:trace, LogTracer.new)
Log.info { "routed to tracing" }
```

## Non-Blocking I/O

Offload file writes to a worker fiber via `src/tracing-subscriber/appender.cr`:

```crystal
appender = RollingFileAppender.new(Rotation::DAILY, "logs", "app")
nb, guard = NonBlocking.new(appender)
FmtLayer.make_writer { nb.make_writer }
```

## Flamegraphs

Generate flamegraph data from span timings via `src/tracing-subscriber/flame.cr`:

```crystal
flame, guard = FlameLayer.with_file("trace.folded")
Registry.default.with(flame).init
# ... run app ...
# cat trace.folded | inferno-flamegraph > flame.svg
```

## Instrumentation

Auto-wrap blocks in spans via `src/tracing/facade_dsl.cr`:

```crystal
@[Tracing::Instrument]
def process(id : Int32)
  Tracing.instrument("process", id: id) do
    # work happens inside span "process"
  end
end
```

## Development

```bash
shards install
crystal tool format --check src spec
ameba src spec
crystal spec            # 141 parity specs
```

## License

MIT — see [LICENSE](LICENSE)
