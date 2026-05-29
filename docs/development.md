# Development

## Setup

```bash
shards install
```

## Project Structure

```
src/
├── tracing.cr                          # Main module, re-exports, requires
├── tracing/                            # tracing-core + tracing facade
│   ├── types.cr                        # Level, LevelFilter, Kind, Callsite::Identifier, Interest
│   ├── metadata.cr                     # Metadata struct
│   ├── field.cr                        # Field, FieldSet, ValueSet, Visit trait
│   ├── callsite.cr                     # Interface trait, DefaultCallsite, Callsites registry
│   ├── span.cr                         # Span::Id, Attributes, Record, Current, Parent
│   ├── event.cr                        # Event type
│   ├── subscriber.cr                   # Subscriber trait, NoSubscriber
│   ├── dispatcher.cr                   # Dispatch, Dispatchers::Manager
│   ├── facade_span.cr                  # Tracing::Span handle (enter/exit/in_scope)
│   ├── facade_dsl.cr                   # Tracing.span, .event, .info, .debug, .warn, .error, .trace
│   ├── facade_macros.cr                # span!, event!, info!, *span! macros
│   └── subscriber_conv.cr              # Tracing::Subscriber.with_default, .set_global_default
└── tracing-subscriber/                 # tracing-subscriber
    ├── registry.cr                     # Registry (Subscriber impl), SpanData
    ├── layer.cr                        # Layer, LayerContext, Layered(S), NoOpLayer, Filtered
    ├── lookup_span.cr                  # LookupSpan trait, SpanRef, event_span
    ├── extensions.cr                   # Extensions type map, ExtensionsMut
    ├── filter.cr                       # LevelFilterLayer
    ├── env_filter.cr                   # EnvFilter, Directive parser
    ├── filter_fn.cr                    # FilterFn (closure-based)
    ├── targets.cr                      # Targets (programmatic target matching)
    └── fmt.cr                          # FmtLayer (compact, pretty, ansi), FieldCollector

spec/
└── tracing_spec.cr                     # 111 parity specs across all crates
```

## Quality Gates

Run all three before submitting:

```bash
crystal tool format --check src spec
ameba src spec
crystal spec            # 111 examples
```

## Porting Workflow

1. Study the upstream Rust source at the pinned commit in `vendor/tracing/`
2. Write failing parity spec first (RED)
3. Implement the minimal Crystal code to pass (GREEN)
4. Run quality gates
5. Update `plans/parity.md` and `plans/inventory/`
6. Commit: `port: <feature name>`

## Upstream Sources

| Crate | Rust Source | Crystal Source |
|-------|------------|----------------|
| tracing-core | `vendor/tracing/tracing-core/src/` | `src/tracing/` |
| tracing | `vendor/tracing/tracing/src/` | `src/tracing/facade_*.cr` |
| tracing-subscriber | `vendor/tracing/tracing-subscriber/src/` | `src/tracing-subscriber/` |

## Makefile

```bash
make install      # shards install
make clean        # remove temp/, build artifacts
```
