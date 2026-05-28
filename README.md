# tracing

A Crystal port of [tokio-rs/tracing](https://github.com/tokio-rs/tracing) — a
framework for instrumenting programs to collect structured, event-based
diagnostic information.

**Upstream pinned at**: `tracing-0.1.44` (commit `2d55f6f`)

## Scope

This port covers the full tracing stack:

- **tracing-core** — foundational primitives (Metadata, Field, Span, Event, Subscriber, Dispatcher)
- **tracing** — instrumentation facade API
- **tracing-subscriber** — subscriber implementations (Layer, Registry, fmt, filter)

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  tracing:
    github: dsisnero/tracing
```

Then run `shards install`.

## Usage

```crystal
require "tracing"
```

## Development

```bash
shards install
crystal tool format --check src spec
ameba src spec
crystal spec
```

## Contributing

1. Fork it (<https://github.com/dsisnero/tracing/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer
