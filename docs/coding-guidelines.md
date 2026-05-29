# Coding Guidelines

## Porting Rules

1. **Upstream behavior is the source of truth.** Port behavior, not Rust style.
   Crystal idioms are fine where semantics stay unchanged.

2. **Explicit numeric widths.** Use `UInt64`, `Int32`, `UInt8` when signedness or
   range matters. Example: `Level : UInt64` enum for optimized integer comparisons
   (`src/tracing/types.cr:10`).

3. **Red-green TDD.** Write a failing parity spec first, then the minimal code
   to pass. See `spec/tracing_spec.cr` for 111 ported parity examples.

4. **Document renames.** When upstream method names differ from Crystal conventions,
   record the mapping in `plans/inventory/tracing-core.md` under "Naming Convention Map".
   Example: `is_event()` → `event?`.

5. **Commit per feature.** Each feature in `plans/parity.md` maps to one commit
   with `port:` prefix.

## Naming Conventions

Crystal idioms vs upstream Rust:

| Rust | Crystal | Convention |
|------|---------|------------|
| `is_event()` | `event?` | predicate drops `is_` |
| `is_span()` | `span?` | same |
| `is_empty()` | `empty?` | same |
| `set_interest(x)` | `interest = x` | setter uses `=` |
| `set_max(x)` | `max = x` | same |
| `get_default()` | `default` | getter drops `get_` |

## Crystal Patterns

### Enums

Use `@[Flags]` for bitmask enums (see `FmtSpan` in `src/tracing-subscriber/fmt.cr:5`).
Use bare `enum` for mutually exclusive values (see `Level` in `src/tracing/types.cr:10`).

### Abstract Classes vs Modules

Use `abstract class` when shared state is needed (`Layer` base class in
`src/tracing-subscriber/layer.cr:5`). Use `module` for pure trait interfaces
(`Subscriber` module in `src/tracing/subscriber.cr`, `LookupSpan` in
`src/tracing-subscriber/lookup_span.cr`).

### Generics

Use generic classes for type-safe composition. Example:
`class Layered(S)` in `src/tracing-subscriber/layer.cr:69` — the type parameter
`S` represents the inner subscriber type.

### Atomic Operations

Use `Atomic(UInt64)` for lock-free counters and `Atomic(UInt8)` for state flags.
CAS (`compare_and_set`) for lock-free linked list registration
(`src/tracing/callsite.cr:49`).

### Pointer Casting for Type-Erasure

When storing heterogeneous types, use `Pointer(Void)` with `malloc` and cast.
See `Extensions` in `src/tracing-subscriber/extensions.cr` for type-erased storage.

## Ameba

Targeted per-method suppressions only. Format:
```crystal
# Port parity: matches upstream <function_name>()
# ameba:disable Naming/AccessorMethodName
def self.set_global_default(subscriber)
```
