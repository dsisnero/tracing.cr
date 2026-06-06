require "./spec_helper"

describe "NonBlocking lossy mode" do
  it "accepts lossy parameter without error" do
    io = IO::Memory.new
    nb, guard = Tracing::NonBlocking.builder(io, buffer_size: 2, lossy: true)
    writer = nb.make_writer
    writer.write("test\n".to_slice)
    guard.close
    nb.should be_a(Tracing::NonBlocking)
  end
end
