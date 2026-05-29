# Porting Parity Status

Upstream: **tokio-rs/tracing** pinned at `tracing-0.1.44` (commit `2d55f6f`)

| Crate | Upstream Version | Status |
|-------|-----------------|--------|
| tracing-core | 0.1.36 | Complete — all types + callsite registry + dispatcher chain |
| tracing | 0.1.44 | Nearly complete — Span handle, DSL, macros, with_default |
| tracing-subscriber | 0.3.23 | In progress — Registry, Layer, LookupSpan, Extensions, FmtLayer, filter, EnvFilter |

## tracing-core

- [x] Level, LevelFilter, Kind, Metadata
- [x] Field, FieldSet, ValueSet, Visit
- [x] Callsite::Identifier, Interest, Interface, DefaultCallsite
- [x] Callsite registry (lock-free linked list, interest caching)
- [x] Span::Id, Attributes, Record, Current
- [x] Parent
- [x] Event
- [x] Subscriber trait, NoSubscriber
- [x] Dispatch (global default, with_default fiber-local, interest rebuild)
- [x] Dispatchers manager (multi-dispatch)
- [ ] `identify_callsite!` / `metadata!` macros (deferred — internal optimization)

## tracing

- [x] Span handle (enter/exit/in_scope lifecycle)
- [x] Dispatch.with_default (fiber-local scoped)
- [x] DSL methods (Tracing.span, .event, .info, .debug, .warn, .error, .trace)
- [x] Macros (span!, event!, info!, debug!, warn!, error!, trace!, *span! variants)
- [x] Entered/EnteredSpan guards
- [x] Level/LevelFilter bi-directional comparisons

## tracing-subscriber

- [x] Registry (Subscriber impl, span storage, current span tracking)
- [x] Layer trait (on_event, on_new_span, on_enter, on_exit, on_register_callsite)
- [x] Layered(S) subscriber (Layer + Subscriber composition)
- [x] LookupSpan trait + SpanRef
- [x] Extensions type map (per-span type-erased storage)
- [x] LevelFilterLayer (filter as Layer)
- [x] FmtLayer (formatted output to IO)
- [x] FmtLayer.with_filter (per-layer level filter)
- [x] Directive parsing (EnvFilter directive: `target[span]=level`)

## Quality Gates

```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```
