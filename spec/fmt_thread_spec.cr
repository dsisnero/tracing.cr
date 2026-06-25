require "./spec_helper"

# Ported from vendor/tracing/tracing-subscriber/src/fmt/format/mod.rs
# (with_thread_ids / with_thread_names). In Crystal, threads map to fibers, so
# these show the current fiber's id / name (see Divergences in parity.md).
describe "FmtLayer thread info (ported from format/mod.rs)" do
  it "with_thread_names shows the fiber name" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).with_thread_names(true)
    subscriber = Tracing::Registry.new.with(layer)
    original = Fiber.current.name
    begin
      Fiber.current.name = "fmt-thread-test"
      Tracing::Dispatch.with_default(Tracing::Dispatch.new(subscriber)) do
        Tracing.event(Tracing::Level::INFO, "ev")
      end
      io.to_s.should contain("fmt-thread-test")
    ensure
      Fiber.current.name = original
    end
  end

  it "with_thread_ids shows the fiber id" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).with_thread_ids(true)
    subscriber = Tracing::Registry.new.with(layer)
    Tracing::Dispatch.with_default(Tracing::Dispatch.new(subscriber)) do
      Tracing.event(Tracing::Level::INFO, "ev")
    end
    io.to_s.should contain(Fiber.current.object_id.to_s)
  end

  it "shows no thread info by default" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io)
    subscriber = Tracing::Registry.new.with(layer)
    original = Fiber.current.name
    begin
      Fiber.current.name = "should-not-appear"
      Tracing::Dispatch.with_default(Tracing::Dispatch.new(subscriber)) do
        Tracing.event(Tracing::Level::INFO, "ev")
      end
      io.to_s.should_not contain("should-not-appear")
    ensure
      Fiber.current.name = original
    end
  end

  it "includes threadName in JSON output" do
    io = IO::Memory.new
    layer = Tracing::FmtLayer.new(io).json.with_thread_names(true)
    subscriber = Tracing::Registry.new.with(layer)
    original = Fiber.current.name
    begin
      Fiber.current.name = "json-thread-test"
      Tracing::Dispatch.with_default(Tracing::Dispatch.new(subscriber)) do
        Tracing.event(Tracing::Level::INFO, "ev")
      end
      JSON.parse(io.to_s.strip)["threadName"].should eq("json-thread-test")
    ensure
      Fiber.current.name = original
    end
  end
end
