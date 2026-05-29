# PR Workflow

## Commits

Format: `port: <feature name>`

Feature commits must be atomic — one feature per commit with all related
source, spec, and inventory changes.

### Examples

```text
port: tracing-core foundational types
port: callsite registry and dispatcher chain
port: tracing facade Span handle, with_default, Level/LevelFilter comparisons
port: tracing facade DSL — span/event creation methods
port: tracing facade macros — span!, event!, level macros
port: tracing-subscriber Registry (Subscriber + span storage)
port: tracing-subscriber Layer trait + Layered subscriber
port: EnvFilter directive parsing, update parity plan
port: FmtLayer compact mode
port: FmtLayer MakeWriter (dynamic writer block)
```

## Before Opening a PR

1. Run all quality gates:
   ```bash
   crystal tool format --check src spec
   ameba src spec
   crystal spec            # 111 examples, 0 failures
   ```

2. Update `plans/parity.md` — check completed features

3. Update `plans/inventory/` — mark module statuses

4. Verify upstream parity:
   ```bash
   ./scripts/check_port_inventory.sh . plans/inventory/rust_port_inventory.tsv vendor/tracing rust
   ```

5. Review the diff: `git diff --stat main...HEAD`

## Review Checklist

- [ ] All quality gates pass (format, ameba, spec)
- [ ] Parity specs ported from upstream tests
- [ ] No dead code or unused imports
- [ ] Crystal naming conventions followed (see `docs/coding-guidelines.md`)
- [ ] Intentional divergences documented with `# ameba:disable` comments
- [ ] `plans/parity.md` and `plans/inventory/` updated
- [ ] Commit messages use `port:` prefix

## Branch Naming

```text
port/<feature-name>      # porting work
fix/<bug-description>    # bug fixes
refactor/<what>          # internal refactoring
docs/<what>              # documentation only
```
