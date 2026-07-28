# Compile-time max level filter — mirrors Rust's STATIC_MAX_LEVEL.
#
# Controlled by Crystal -D flags:
#   -Dtrace_max_off     → strip ALL tracing from binary
#   -Dtrace_max_error   → only ERROR events
#   -Dtrace_max_warn    → ERROR + WARN
#   -Dtrace_max_info    → ERROR + WARN + INFO
#   -Dtrace_max_debug   → ERROR + WARN + INFO + DEBUG
#   -Dtrace_max_trace   → everything (default, no flag needed)
#
# Ported from vendor/tracing/tracing/src/level_filters.rs:66-112
{% begin %}
  {% if flag?(:trace_max_off) %}
    STATIC_MAX_LEVEL = LevelFilter.off
  {% elsif flag?(:trace_max_error) %}
    STATIC_MAX_LEVEL = LevelFilter.error
  {% elsif flag?(:trace_max_warn) %}
    STATIC_MAX_LEVEL = LevelFilter.warn
  {% elsif flag?(:trace_max_info) %}
    STATIC_MAX_LEVEL = LevelFilter.info
  {% elsif flag?(:trace_max_debug) %}
    STATIC_MAX_LEVEL = LevelFilter.debug
  {% else %}
    STATIC_MAX_LEVEL = LevelFilter.trace
  {% end %}
{% end %}

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
  {% if flag?(:trace_max_off) %}
    Tracing::Span.none
  {% else %}
    Tracing.span({{ level }}, {{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro child_span!(parent, level, name, **fields)
  {% if flag?(:trace_max_off) %}
    Tracing::Span.none
  {% else %}
    Tracing.child_span({{ parent }}, {{ level }}, {{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro trace_span!(name, **fields)
  {% if flag?(:trace_max_off) || flag?(:trace_max_error) || flag?(:trace_max_warn) || flag?(:trace_max_info) || flag?(:trace_max_debug) %}
    Tracing::Span.none
  {% else %}
    Tracing::Span.new(Metadata.new({{ name }}, {{ name }}, Level::TRACE, kind: Kind::SPAN))
  {% end %}
end

macro debug_span!(name, **fields)
  {% if flag?(:trace_max_off) || flag?(:trace_max_error) || flag?(:trace_max_warn) || flag?(:trace_max_info) %}
    Tracing::Span.none
  {% else %}
    Tracing.span(Level::DEBUG, {{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro info_span!(name, **fields)
  {% if flag?(:trace_max_off) || flag?(:trace_max_error) || flag?(:trace_max_warn) %}
    Tracing::Span.none
  {% else %}
    Tracing.span(Level::INFO, {{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro warn_span!(name, **fields)
  {% if flag?(:trace_max_off) || flag?(:trace_max_error) %}
    Tracing::Span.none
  {% else %}
    Tracing.span(Level::WARN, {{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro error_span!(name, **fields)
  {% if flag?(:trace_max_off) %}
    Tracing::Span.none
  {% else %}
    Tracing.span(Level::ERROR, {{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro event!(level, name, **fields)
  {% if flag?(:trace_max_off) %}
    # no-op — compile-time stripped
  {% else %}
    Tracing.event({{ level }}, {{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro trace!(name, **fields)
  {% if flag?(:trace_max_off) || flag?(:trace_max_error) || flag?(:trace_max_warn) || flag?(:trace_max_info) || flag?(:trace_max_debug) %}
    # compile-time stripped
  {% else %}
    Tracing.trace({{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro debug!(name, **fields)
  {% if flag?(:trace_max_off) || flag?(:trace_max_error) || flag?(:trace_max_warn) || flag?(:trace_max_info) %}
    # compile-time stripped
  {% else %}
    Tracing.debug({{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro info!(name, **fields)
  {% if flag?(:trace_max_off) || flag?(:trace_max_error) || flag?(:trace_max_warn) %}
    # compile-time stripped
  {% else %}
    Tracing.info({{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro warn!(name, **fields)
  {% if flag?(:trace_max_off) || flag?(:trace_max_error) %}
    # compile-time stripped
  {% else %}
    Tracing.warn({{ name }}, {{ fields.double_splat }})
  {% end %}
end

macro error!(name, **fields)
  {% if flag?(:trace_max_off) %}
    # compile-time stripped
  {% else %}
    Tracing.error({{ name }}, {{ fields.double_splat }})
  {% end %}
end

# Ported from tracing-macros/src/lib.rs (trace_dbg!)
macro trace_dbg!(expr)
  {% if flag?(:trace_max_off) || flag?(:trace_max_error) || flag?(:trace_max_warn) || flag?(:trace_max_info) %}
    {{ expr }}
  {% else %}
    %val = {{ expr }}
    info!("trace_dbg", value: %val, expr: {{ expr.stringify }})
    %val
  {% end %}
end
