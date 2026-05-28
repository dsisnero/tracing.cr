# Testing

## Running Tests

```bash
crystal spec
```

## Parity Tests

Specs in `spec/` aim for behavioral parity with the upstream Rust tests in
`vendor/tracing/`. Each Crystal spec should correspond to an upstream Rust test
where applicable.

## Test Organization

- `spec/tracing/` — parity specs for the tracing library
- `spec/tracing-core/` — parity specs for tracing-core
- `spec/tracing-subscriber/` — parity specs for tracing-subscriber
