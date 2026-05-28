# Architecture

The tracing framework is structured in three layers:

1. **tracing-core** — foundational primitives: `Metadata`, `Field`, `Span`, `Event`,
   `Subscriber`, `Dispatcher`
2. **tracing** — instrumentation facade: macros (`span!`, `event!`), `Instrument` trait
3. **tracing-subscriber** — subscriber implementations: `Layer`, `Registry`, `fmt`, `filter`

See `src/tracing/` for the Crystal implementation and `vendor/tracing/` for the upstream Rust source.
