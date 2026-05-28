# Agents Guide

## Source of Truth

- **Upstream**: https://github.com/tokio-rs/tracing (Rust)
- **Submodule**: `vendor/tracing/` pinned at tag `tracing-0.1.44` (commit `2d55f6f`)
- **Scope**: Full stack port — `tracing-core`, `tracing`, `tracing-subscriber`
- **Language**: Rust → Crystal

## Upstream Crate Versions (pinned)

| Crate | Version | Tag |
|-------|---------|-----|
| tracing-core | 0.1.36 | tracing-core-0.1.36 |
| tracing | 0.1.44 | tracing-0.1.44 |
| tracing-subscriber | 0.3.23 | tracing-subscriber-0.3.23 |

## Quality Gates

Run all three before closing any feature:

```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```

## Porting Rules

1. Upstream behavior is the source of truth — port behavior, not style.
2. Use explicit numeric widths when signedness or range matters.
3. Use `Bytes` for binary data, not `String`.
4. Port upstream tests as first-class work.
5. Update `plans/inventory/` after every feature completion.
6. Document any intentional divergence.

## Directory Layout

```
src/tracing/          Crystal implementation
spec/                 Crystal specs (parity tests)
vendor/tracing/       Upstream Rust source (submodule)
plans/                Parity planning and inventory
plans/parity.md       High-level parity status
plans/inventory/      Per-module parity tracking
```

## Porting Order

1. `tracing-core` — foundational types (Metadata, Field, Span, Event, Subscriber, Dispatcher)
2. `tracing` — instrumentation facade (span!, event!, macros, Instrument)
3. `tracing-subscriber` — subscriber implementations (Layer, Registry, fmt, filter)
