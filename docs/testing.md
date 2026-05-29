# Testing

## Running Tests

```bash
crystal spec            # 111 parity specs across all crates
```

## Test Organization

All tests in `spec/tracing_spec.cr` (111 examples), organized by crate:

| Section | Examples | Source |
|---------|----------|--------|
| Level comparisons | 4 | `vendor/tracing/tracing-core/src/metadata.rs` doc examples |
| LevelFilter comparisons | 8 | same |
| Level parse/format | 8 | same |
| Kind flags | 3 | same |
| Span::Id | 2 | `vendor/tracing/tracing-core/src/span.rs` |
| Parent | 3 | `vendor/tracing/tracing-core/src/parent.rs` |
| Span lifecycle | 3 | `vendor/tracing/tracing/src/span.rs` |
| Dispatch with_default | 1 | `vendor/tracing/tracing/src/dispatcher.rs` |
| DSL methods (span, event, level) | 6 | `vendor/tracing/tracing/src/macros.rs` |
| Macros (span!, event!, info!, etc.) | 7 | same |
| Registry (span storage, lookup) | 5 | `vendor/tracing/tracing-subscriber/src/registry/` |
| Layer (event/span observation) | 2 | `vendor/tracing/tracing-subscriber/src/layer/` |
| LookupSpan + event_span | 3 | `vendor/tracing/tracing-subscriber/src/layer/tests.rs` |
| Extensions (type map) | 5 | `vendor/tracing/tracing-subscriber/src/registry/extensions.rs` |
| LevelFilterLayer | 3 | `vendor/tracing/tracing-subscriber/src/filter/level.rs` |
| EnvFilter directive parsing | 8 | `vendor/tracing/tracing-subscriber/src/filter/env/directive.rs` |
| EnvFilter layer | 3 | same |
| FilterFn | 2 | `vendor/tracing/tracing-subscriber/src/filter/filter_fn.rs` |
| Targets | 3 | `vendor/tracing/tracing-subscriber/src/filter/targets.rs` |
| FmtLayer (format, compact, pretty, ansi) | 11 | `vendor/tracing/tracing-subscriber/src/fmt/` |
| MakeWriter | 2 | `vendor/tracing/tracing-subscriber/src/fmt/writer.rs` |
| FmtSpan config | 4 | `vendor/tracing/tracing-subscriber/src/fmt/fmt_layer.rs` |
| Subscriber convenience | 3 | `vendor/tracing/tracing/src/subscriber.rs` |
| Nil-as-Layer | 2 | `vendor/tracing/tracing-subscriber/src/layer/` |
| and_then combinator | 2 | same |
| target override | 1 | `vendor/tracing/tracing/src/macros.rs` |
| Span record | 1 | `vendor/tracing/tracing/src/span.rs` |
| LevelFilter.current | 1 | `vendor/tracing/tracing-core/src/metadata.rs` |

## Test Helpers

Spec helpers are defined at the bottom of `spec/tracing_spec.cr`:
- `TestSubscriber` — counts new_span, enter, exit, event calls
- `EventCollector` — records event names for filter verification
- `EventLog` — records targets
- `SpanRecordLog` — verifies span field recording

## Writing Parity Tests

1. Find the upstream test in `vendor/tracing/`
2. Port the test logic (not exact Rust syntax) to Crystal
3. Use `Dispatch.with_default` for scoped test isolation
4. Avoid `Dispatch.global_default =` (can only be set once per process)
5. Assert behavior, not implementation details

Example port from `vendor/tracing/tracing-core/src/metadata.rs:1060`:
```crystal
# Rust: assert_eq!("error".parse::<Level>().unwrap(), Level::ERROR);
it "parses string names" do
  Level.parse("error").should eq(Level::ERROR)
end
```
