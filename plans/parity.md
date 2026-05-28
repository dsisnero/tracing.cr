# Porting Parity Status

Upstream: **tokio-rs/tracing** pinned at `tracing-0.1.44` (commit `2d55f6f`)

| Crate | Upstream Version | Status |
|-------|-----------------|--------|
| tracing-core | 0.1.36 | Nearly complete — callsite registry + dispatcher chain done |
| tracing | 0.1.44 | Not started (needs tracing-core complete) |
| tracing-subscriber | 0.3.23 | Not started (needs tracing complete) |

## Porting Order

1. **tracing-core** — foundational types + infrastructure
   - [x] Level, LevelFilter, Kind, Metadata
   - [x] Field, FieldSet, ValueSet, Visit
   - [x] Callsite::Identifier, Interest, Interface, DefaultCallsite
   - [x] Callsite registry (lock-free linked list, interest caching)
   - [x] Span::Id, Attributes, Record, Current
   - [x] Parent
   - [x] Event
   - [x] Subscriber trait, NoSubscriber
   - [x] Dispatch (global default + callsite interest rebuild integration)
   - [x] Dispatchers manager (multi-dispatch)
   - [ ] Thread-local dispatch (`with_default`)
   - [ ] `identify_callsite!` / `metadata!` macros
2. **tracing** — instrumentation facade (after core is done)
3. **tracing-subscriber** — subscriber implementations (after tracing is done)

## Quality Gates

```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```
