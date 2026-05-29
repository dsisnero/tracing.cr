module Tracing
  # Annotation marking a method for instrumentation.
  #
  # Ported from upstream `#[tracing::instrument]`.
  #
  # Usage:
  #   class MyService
  #     @[Tracing::Instrument]
  #     def process(id : Int32)
  #       Tracing.instrument("process", id: id) do
  #         # work
  #       end
  #     end
  #   end
  #
  # NOTE: Crystal does not support proc macros like Rust's `#[instrument]`.
  # Use `Tracing.instrument(name, **fields) { ... }` for automatic span
  # wrapping of blocks. The annotation serves as documentation and may
  # be used by future compile-time tooling.
  annotation Instrument
  end
end
