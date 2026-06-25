require "./spec_helper"
require "file_utils"

# Ported from vendor/tracing/tracing-appender/src/rolling/builder.rs and the
# join_date / prune_old_logs logic in rolling.rs.

private def with_rolling_dir(name : String, &)
  dir = File.join("temp", name)
  FileUtils.rm_rf(dir)
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

describe "RollingFileAppender::Builder (ported from rolling/builder.rs)" do
  it "names the file `prefix.suffix` for NEVER rotation" do
    with_rolling_dir("rolling_never_pfx_sfx") do |dir|
      appender = Tracing::RollingFileAppender.builder
        .rotation(Tracing::Rotation::NEVER)
        .filename_prefix("app")
        .filename_suffix("log")
        .build(dir)
      appender.write("x\n".to_slice)
      appender.close
      File.exists?(File.join(dir, "app.log")).should be_true
    end
  end

  it "names the file `prefix` when only a prefix is set (NEVER)" do
    with_rolling_dir("rolling_never_pfx") do |dir|
      appender = Tracing::RollingFileAppender.builder
        .rotation(Tracing::Rotation::NEVER)
        .filename_prefix("app")
        .build(dir)
      appender.write("x\n".to_slice)
      appender.close
      File.exists?(File.join(dir, "app")).should be_true
    end
  end

  it "names the file `suffix` when only a suffix is set (NEVER)" do
    with_rolling_dir("rolling_never_sfx") do |dir|
      appender = Tracing::RollingFileAppender.builder
        .rotation(Tracing::Rotation::NEVER)
        .filename_suffix("log")
        .build(dir)
      appender.write("x\n".to_slice)
      appender.close
      File.exists?(File.join(dir, "log")).should be_true
    end
  end

  it "names the file `prefix.date.suffix` for DAILY rotation" do
    with_rolling_dir("rolling_daily") do |dir|
      appender = Tracing::RollingFileAppender.builder
        .rotation(Tracing::Rotation::DAILY)
        .filename_prefix("app")
        .filename_suffix("log")
        .build(dir)
      appender.write("x\n".to_slice)
      appender.close
      Dir["#{dir}/app.*.log"].size.should be > 0
    end
  end

  it "treats an empty prefix/suffix as unset" do
    with_rolling_dir("rolling_empty") do |dir|
      appender = Tracing::RollingFileAppender.builder
        .rotation(Tracing::Rotation::NEVER)
        .filename_prefix("app")
        .filename_suffix("")
        .build(dir)
      appender.write("x\n".to_slice)
      appender.close
      File.exists?(File.join(dir, "app")).should be_true
    end
  end

  it "max_log_files prunes the oldest matching logs" do
    with_rolling_dir("rolling_prune") do |dir|
      base = Time.utc(2024, 1, 1)
      ["app.2023-01-01.log", "app.2023-06-01.log", "app.2023-12-01.log"].each_with_index do |name, i|
        path = File.join(dir, name)
        File.write(path, "old")
        File.utime(base + i.days, base + i.days, path)
      end

      Tracing::RollingFileAppender.builder
        .rotation(Tracing::Rotation::DAILY)
        .filename_prefix("app")
        .filename_suffix("log")
        .max_log_files(2)
        .build(dir)
        .close

      remaining = Dir.children(dir).select(&.starts_with?("app.")).sort!
      remaining.includes?("app.2023-01-01.log").should be_false
      remaining.includes?("app.2023-06-01.log").should be_false
      remaining.includes?("app.2023-12-01.log").should be_true
      remaining.size.should eq(2) # newest kept old file + the new file
    end
  end
end
