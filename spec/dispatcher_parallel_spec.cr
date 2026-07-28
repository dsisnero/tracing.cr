require "spec"
require "../src/tracing/core/types"
require "../src/tracing/core/field"
require "../src/tracing/core/metadata"
require "../src/tracing/core/callsite"
require "../src/tracing/core/span"
require "../src/tracing/core/event"
require "../src/tracing/core/subscriber"
require "../src/tracing/core/dispatcher"

describe Tracing::Core::Dispatch do
  it "keeps fiber-local dispatch state safe across parallel contexts" do
    context = Fiber::ExecutionContext::Parallel.new("dispatch-spec", 4)
    completed = Channel(Nil).new

    200.times do
      context.spawn do
        20.times do
          prior = Tracing::Core::Dispatch.current
          dispatch = Tracing::Core::Dispatch.new
          Tracing::Core::Dispatch.with_default(dispatch) do
            Fiber.yield
            Tracing::Core::Dispatch.current.should eq(dispatch)
          end
          Tracing::Core::Dispatch.current.should eq(prior)
        end
        completed.send(nil)
      end
    end

    200.times { completed.receive }
  end
end
