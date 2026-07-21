require "./spec_helper"

describe "NonBlocking" do
  it "writes events through a worker fiber" do
    io = IO::Memory.new
    nb, guard = Tracing::NonBlocking.new(io)
    writer = nb.make_writer

    writer.write("hello\n".to_slice)
    writer.write("world\n".to_slice)

    guard.close
    output = io.to_s
    output.should contain("hello")
    output.should contain("world")
  end

  it "WorkerGuard flushes on close" do
    io = IO::Memory.new
    nb, guard = Tracing::NonBlocking.new(io)
    writer = nb.make_writer
    writer.write("buffered\n".to_slice)
    guard.close
    io.to_s.should contain("buffered")
  end

  it "builder accepts custom buffer size" do
    io = IO::Memory.new
    nb, guard = Tracing::NonBlocking.builder(io, buffer_size: 1024)
    nb.should be_a(Tracing::NonBlocking)
    guard.close
  end

  describe "lossy mode" do
    it "drops messages when buffer is full" do
      io = IO::Memory.new
      nb, guard = Tracing::NonBlockingBuilder.new
        .buffered_lines_limit(1)
        .lossy(true)
        .finish(io)
      writer = nb.make_writer
      error_count = nb.error_counter

      100.times { writer.write("x".to_slice) }

      guard.close
      error_count.dropped_lines.should be > 0
    end

    it "does not drop when not lossy (backpressure)" do
      io = IO::Memory.new
      nb, guard = Tracing::NonBlocking.builder(io, buffer_size: 256, lossy: false)
      writer = nb.make_writer
      error_count = nb.error_counter

      10.times { writer.write("test\n".to_slice) }

      guard.close
      error_count.dropped_lines.should eq(0)
    end
  end

  describe "NonBlockingBuilder" do
    it "builds with default configuration" do
      io = IO::Memory.new
      nb, guard = Tracing::NonBlockingBuilder.new.finish(io)
      nb.should be_a(Tracing::NonBlocking)
      guard.close
    end

    it "configures buffered_lines_limit" do
      io = IO::Memory.new
      nb, guard = Tracing::NonBlockingBuilder.new
        .buffered_lines_limit(2048)
        .finish(io)
      guard.close
    end

    it "configures lossy mode" do
      io = IO::Memory.new
      nb, guard = Tracing::NonBlockingBuilder.new
        .lossy(true)
        .finish(io)
      nb.error_counter.should be_a(Tracing::ErrorCounter)
      guard.close
    end

    it "configures thread_name" do
      io = IO::Memory.new
      nb, guard = Tracing::NonBlockingBuilder.new
        .thread_name("test-worker")
        .finish(io)
      guard.close
    end
  end

  describe "ErrorCounter" do
    it "starts at zero" do
      counter = Tracing::ErrorCounter.new
      counter.dropped_lines.should eq(0)
    end

    it "increments saturating" do
      counter = Tracing::ErrorCounter.new
      counter.incr_saturating
      counter.dropped_lines.should eq(1)
      counter.incr_saturating
      counter.dropped_lines.should eq(2)
    end
  end
end
