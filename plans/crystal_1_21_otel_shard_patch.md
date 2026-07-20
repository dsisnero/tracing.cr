# Crystal 1.21 OpenTelemetry Shard Patch Handoff

Date: 2026-07-20

This repo needed compatibility fixes in upstream shards under `lib/`:

- `wyhaines/opentelemetry-api.cr` `v0.5.1`
- `wyhaines/opentelemetry-sdk.cr` `v0.6.2`
- `wyhaines/nbchannel.cr` `v0.1.0`

Following the shard patch workflow, the fixes were reproduced and implemented in temporary fork workspaces under `temp/` on branch `codex/crystal-1.21-compat`.

## Local branch state

- `temp/opentelemetry-api` at commit `79ac550`
- `temp/opentelemetry-sdk` at commit `235dbf6`
- `temp/nbchannel` at commit `8ead6a9`

## Repro before patch

`nbchannel`:

```bash
CRYSTAL_CACHE_DIR=/private/tmp/tracing-shard-eval-cache crystal eval \
  'require "./temp/nbchannel/src/nbchannel"; ch = NBChannel(Int32).new; spawn { ch.receive? }; Fiber.yield'
```

Failed with `undefined constant Crystal::Scheduler`.

`opentelemetry-sdk`:

```bash
CRYSTAL_CACHE_DIR=/private/tmp/tracing-shard-eval-cache \
CRYSTAL_PATH="$PWD/temp/opentelemetry-api/src:$PWD/lib:/opt/homebrew/Cellar/crystal/1.21.0/share/crystal/src" \
crystal eval 'require "./temp/opentelemetry-sdk/src/opentelemetry-sdk"'
```

Failed with the abstract contract error on `OpenTelemetry::Event#parent_span=`.

## Fix summary

`opentelemetry-api`:

- aligned span/event/context/status APIs with Crystal 1.21 abstract typing requirements
- added explicit `Slice(UInt8)` return types for id generators
- kept concrete `Event` and `Span` array assignment working at the setter boundary

`opentelemetry-sdk`:

- aligned event/span/context/sampler signatures with the API shard changes
- fixed exporter debug logging and JSON builder usage
- added explicit id generator return types
- added a focused Crystal 1.21 compatibility spec

`nbchannel`:

- replaced the old scheduler reschedule call with `Fiber.suspend`
- added a focused Crystal 1.21 compatibility spec

## Shard verification

Passed:

- `temp/nbchannel`: `crystal spec spec/crystal_1_21_compat_spec.cr`
- `temp/nbchannel`: `crystal build src/nbchannel.cr`
- `temp/opentelemetry-api`: `crystal build src/opentelemetry-api.cr`
- `temp/opentelemetry-sdk`: `crystal spec spec/crystal_1_21_compat_spec.cr`
- `temp/opentelemetry-sdk`: `crystal build src/opentelemetry-sdk.cr`

Remaining upstream shard-suite notes:

- `temp/opentelemetry-api` full spec run hit an existing time-equality style failure in `spec/event_spec.cr` (`wall_timestamp` equal to `Time.utc` in the assertion window).
- `temp/nbchannel` full spec run still hit an existing throughput-sensitive failure in `spec/nbchannel_spec.cr` nonblocking receive expectations.

These did not block the host repo because the focused compatibility proofs passed, the shards built, and the host repo gates passed.

## Host repo verification

The host repo was temporarily pointed at the local patched shard paths for validation, then restored to the normal GitHub shard declarations.

Passed on 2026-07-20:

- `crystal tool format --check src spec`
- `ameba src`
- `ameba spec`
- `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec spec/tracing_spec.cr --fail-fast --error-trace --verbose`
- `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec --fail-fast --error-trace --verbose`

Host results:

- `spec/tracing_spec.cr`: `226 examples, 0 failures`
- full suite: `283 examples, 0 failures`

## Upstream push blocker

GitHub push/fork work was blocked on 2026-07-20:

- `gh auth status` reported an invalid token for account `dsisnero`
- `gh repo view` failed to reach `api.github.com`

Because of that, the local compatibility branches were committed but not pushed, and no upstream PR was created.
