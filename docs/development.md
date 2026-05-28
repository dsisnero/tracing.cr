# Development

## Setup

```bash
shards install
```

## Quality Gates

Before submitting changes, ensure all pass:

```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```

## Porting Workflow

1. Study the upstream Rust source in `vendor/tracing/`
2. Implement in `src/tracing/`
3. Write parity specs in `spec/`
4. Update `plans/inventory/`
5. Run quality gates
