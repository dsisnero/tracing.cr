# Macros matching upstream tracing's `span!`, `event!`, and level macros.
#
# Usage (identical Rust-style):
#   span!(Level::INFO, "my_span", answer: 42)
#   event!(Level::DEBUG, "my_event", key: "value")
#   info!("something_happened", user_id: 123)
#   debug_span!("db_work", table: "users")
#
# Differences from Rust:
#   - Field assignment uses `:` (Crystal named args) not `=` (Rust)
#   - No parent:/target: override — use child_span! or target_span!

macro span!(level, name, **fields)
  Tracing.span({{ level }}, {{ name }}, {{ fields.double_splat }})
end

macro child_span!(parent, level, name, **fields)
  Tracing.child_span({{ parent }}, {{ level }}, {{ name }}, {{ fields.double_splat }})
end

macro trace_span!(name, **fields)
  Tracing.span(Level::TRACE, {{ name }}, {{ fields.double_splat }})
end

macro debug_span!(name, **fields)
  Tracing.span(Level::DEBUG, {{ name }}, {{ fields.double_splat }})
end

macro info_span!(name, **fields)
  Tracing.span(Level::INFO, {{ name }}, {{ fields.double_splat }})
end

macro warn_span!(name, **fields)
  Tracing.span(Level::WARN, {{ name }}, {{ fields.double_splat }})
end

macro error_span!(name, **fields)
  Tracing.span(Level::ERROR, {{ name }}, {{ fields.double_splat }})
end

macro event!(level, name, **fields)
  Tracing.event({{ level }}, {{ name }}, {{ fields.double_splat }})
end

macro trace!(name, **fields)
  Tracing.trace({{ name }}, {{ fields.double_splat }})
end

macro debug!(name, **fields)
  Tracing.debug({{ name }}, {{ fields.double_splat }})
end

macro info!(name, **fields)
  Tracing.info({{ name }}, {{ fields.double_splat }})
end

macro warn!(name, **fields)
  Tracing.warn({{ name }}, {{ fields.double_splat }})
end

macro error!(name, **fields)
  Tracing.error({{ name }}, {{ fields.double_splat }})
end

# Ported from tracing-macros/src/lib.rs (trace_dbg!)
# Evaluates an expression, emits a DEBUG tracing event with
# the value and stringified expression, then returns the value.
macro trace_dbg!(expr)
  %val = {{ expr }}
  info!("trace_dbg", value: %val, expr: {{ expr.stringify }})
  %val
end
