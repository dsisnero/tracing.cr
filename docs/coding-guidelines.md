# Coding Guidelines

1. **Port behavior, not style.** Match upstream Rust semantics. Crystal idioms are fine
   where they don't change observable behavior.
2. **Use explicit numeric widths** when signedness or range matters (e.g., `UInt64` not `Int`).
3. **Use `Bytes` for binary data**, not `String`.
4. **Port upstream tests** as first-class work alongside implementation.
5. **Document intentional divergence** from upstream with comments linking to the upstream source.
