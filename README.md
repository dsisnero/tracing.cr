# tracing

A Crystal port of [tokio-rs/tracing](https://github.com/tokio-rs/tracing):
structured, event-based diagnostics for Crystal programs.

- Current version: `0.5.1`
- Upstream pin: `tracing-0.1.44` (`2d55f6f`)
- Current status: core facade, subscriber stack, appender, flame, log bridge,
  mock, error/span trace, attributes, concurrency helpers, and OpenTelemetry
  bridge are all shipped in `src/`

## Documentation

| Document | Purpose |
|----------|---------|
| [Architecture](docs/architecture.md) | Runtime structure, data flow, public subsystems |
| [Development](docs/development.md) | Setup, source tree, local workflow |
| [Coding Guidelines](docs/coding-guidelines.md) | Porting and Crystal style rules |
| [Testing](docs/testing.md) | Quality gates and test organization |
| [PR Workflow](docs/pr-workflow.md) | Review checklist and branch/commit conventions |
| [Changelog](CHANGELOG.md) | Release history |
| [Parity Status](plans/parity.md) | Shipped feature ledger vs upstream |

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

Tracing.fmt
  .compact
  .with_target(true)
  .with_max_level(Tracing::LevelFilter::INFO)
  .init

span!(Tracing::Level::INFO, "request", method: "GET").in_scope do
  info!("request.started", user_id: 42)
end
```

## Public Surface

The current entrypoint is [src/tracing.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing.cr:1).
It requires and re-exports:

- `src/tracing/core/` for metadata, fields, spans, events, subscribers, and dispatch
- `src/tracing/` facade files for `Tracing.span`, `Tracing.event`, `span!`, `info!`, and `Tracing::Span`
- `src/tracing/subscriber/` for registry, layers, filters, formatting, reload, appenders, flame, log bridge, mock subscriber, and `SpanTrace`
- `src/tracing/opentelemetry/layer.cr` for `Tracing::OpenTelemetryLayer`
- `src/tracing/concurrency*` for fiber and channel helpers

## Core Concepts

### Spans

Spans represent work with duration and context.

```crystal
span = span!(Tracing::Level::INFO, "request", method: "GET")

span.in_scope do
  span.record(path: "/users")
  info!("request.authenticated", user: "alice")
end
```

### Events

Events are point-in-time records, optionally attached to the current span.

```crystal
info!("boot", port: 8080)

span!(Tracing::Level::DEBUG, "db_query").in_scope do
  debug!("query.executed", rows: 100, duration_ms: 12)
end
```

### Subscribers and Layers

`Tracing::Registry` stores span state. `Tracing::Layer` implementations observe
that state and render or export it.

```crystal
registry = Tracing::Registry.default
  .with(Tracing::FmtLayer.new(STDOUT).compact)
  .with(Tracing::EnvFilter.new("info,my_app=debug"))

registry.init
```

## Formatting

The formatting layer lives at [src/tracing/subscriber/fmt.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing/subscriber/fmt.cr:1).
There are two common entrypoints:

- `Tracing.fmt` for the builder API
- `Tracing::FmtLayer.new(...)` for direct layer composition

### Builder API

```crystal
Tracing.fmt
  .pretty
  .with_target(true)
  .with_thread_ids(true)
  .with_max_level(Tracing::LevelFilter::DEBUG)
  .init
```

### JSON Output

```crystal
Tracing.fmt
  .json
  .flatten_event(true)
  .with_current_span(true)
  .with_span_list(true)
  .init
```

Current JSON controls:

- `flatten_event(true)` moves event fields to the root object
- `with_current_span(false)` omits the current span name
- `with_span_list(false)` omits the root-to-leaf span list

## Filtering

The current filter surface lives under `src/tracing/subscriber/`.

```crystal
# Level threshold
fmt = Tracing::FmtLayer.new(STDOUT).with_filter(Tracing::LevelFilter::INFO)

# Environment grammar
env = Tracing::EnvFilter.new("info,my_app=debug,my_app[db]=trace")

# Closure-based
warn_only = Tracing::FilterFn.new { |meta| meta.level <= Tracing::Level::WARN }

# Programmatic targets
targets = Tracing::Targets.new
  .with_target("my_app", Tracing::Level::DEBUG)
  .with_default(Tracing::Level::INFO)
```

Filter combinators are also shipped:

```crystal
combined = targets.and(env.not)
```

## Runtime Reloading

The reload layer is implemented in [src/tracing/subscriber/reload.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing/subscriber/reload.cr:1).

```crystal
builder = Tracing.fmt
  .with_max_level(Tracing::LevelFilter::INFO)
  .with_filter_reloading

builder.init

handle = builder.reload_handle
handle.reload(Tracing::LevelFilterLayer.new(Tracing::LevelFilter::DEBUG))
```

## Crystal Log Bridge

Forward Crystal `Log` entries into tracing with
[src/tracing/subscriber/log_tracer.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing/subscriber/log_tracer.cr:1).

```crystal
Tracing.fmt.compact.init
Log.setup(:trace, Tracing::LogTracer.new)

Log.info { "routed to tracing" }
```

## Non-Blocking Output and Rotation

Appender support lives in [src/tracing/subscriber/appender.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing/subscriber/appender.cr:1).

```crystal
appender = Tracing::RollingFileAppender
  .builder
  .rotation(Tracing::Rotation::DAILY)
  .filename_prefix("app")
  .filename_suffix("log")
  .build("logs")

non_blocking, guard = Tracing::NonBlocking.new(appender)

Tracing::Registry.default
  .with(Tracing::FmtLayer.make_writer { non_blocking.make_writer }.compact)
  .init
```

Keep `guard` alive until shutdown so the worker can flush buffered writes.

Current appender features:

- `NonBlocking` worker fiber + `WorkerGuard`
- `RollingFileAppender`
- builder support for `rotation`, `filename_prefix`, `filename_suffix`, `max_log_files`

## Flame Output

`Tracing::FlameLayer` is ported in [src/tracing/subscriber/flame.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing/subscriber/flame.cr:1).
It writes folded stack output for external tools such as `inferno-flamegraph`.

```crystal
flame, guard = Tracing::FlameLayer.with_file("trace.folded")
Tracing::Registry.default.with(flame).init

# ... run app ...
# cat trace.folded | inferno-flamegraph > flame.svg
```

This is flamegraph/flamechart data, not Chrome trace format.
Keep `guard` alive until shutdown so remaining span samples are flushed.

## OpenTelemetry

The OpenTelemetry bridge is implemented in
[src/tracing/opentelemetry/layer.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing/opentelemetry/layer.cr:1).

```crystal
require "opentelemetry-api"
require "opentelemetry-sdk"

exporter = OpenTelemetry::Exporter.new(:io, io: STDOUT)
provider = OpenTelemetry::TraceProvider.new(
  service_name: "my_app",
  exporter: exporter
)

Tracing::Registry.default
  .with(
    Tracing::OpenTelemetryLayer.new(provider)
      .with_level(Tracing::Level::INFO)
      .with_context_activation(true)
      .with_target(true)
  )
  .init

span!(Tracing::Level::INFO, "request").in_scope do
  info!("request.started", user: "alice")
end
```

Current OTel behavior:

- root and child spans export on span close
- contextual events become OTel span events
- `otel.name`, `otel.kind`, `otel.status_code`, and `otel.status_description` are mapped from tracing fields
- error events can update span status and emit exception-style attributes
- context activation tracks the current trace/span on the active fiber

Note: those OTel override fields are read as dotted keys such as `otel.kind`.
The current Crystal facade is ergonomic for identifier-style named fields; if you
need dotted override keys today, inject them through lower-level field/value
construction rather than plain named args.

## Concurrency Helpers

Concurrency helpers are split across `src/tracing/concurrency*`.

```crystal
require "tracing/concurrency"
require "tracing/concurrency/channel_ext"

done = Tracing::Concurrency.spawn(name: "worker", job: "reindex") do
  info!("worker.started")
  42
end

result = done.receive

channel = Channel(String).new
traced = channel.traced("jobs")
```

Shipped helpers:

- `Tracing::Concurrency.spawn`
- `Tracing::Concurrency.spawn_with_span`
- `Tracing::Concurrency.with_subscriber`
- `Fiber.spawn_traced`
- `Channel#traced`
- `Tracing::Concurrency::TracedChannel`

## Instrumentation Helpers

```crystal
@[Tracing::Instrument]
def process(id : Int32)
  Tracing.instrument("process", id: id) do
    info!("process.started")
  end
end
```

## Development

```bash
shards install
crystal tool format --check src spec
ameba src spec
crystal spec
```

The current suite contains `283` examples in `spec/tracing_spec.cr`.

## License

MIT — see [LICENSE](LICENSE)
