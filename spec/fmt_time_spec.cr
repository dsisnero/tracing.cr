require "./spec_helper"
require "../src/tracing/subscriber/fmt/time"

module Tracing::FmtTime
  describe DateTime do
    it "formats ISO 8601 timestamps correctly for the full i64 range (musl algorithm)" do
      cases = [
        {"1970-01-01T00:00:00.000000Z", 0_i64, 0_u32},

        {"1970-01-01T00:00:00.000001Z", 0_i64, 1_u32},
        {"1970-01-01T00:00:00.500000Z", 0_i64, 500_000_u32},
        {"1970-01-01T00:00:01.000001Z", 1_i64, 1_u32},
        {"1970-01-01T00:01:01.000001Z", 61_i64, 1_u32},
        {"1970-01-01T01:01:01.000001Z", 3661_i64, 1_u32},
        {"1970-01-02T01:01:01.000001Z", 90061_i64, 1_u32},

        {"1969-12-31T23:59:59.000000Z", -1_i64, 0_u32},
        {"1969-12-31T23:59:59.000001Z", -1_i64, 1_u32},
        {"1969-12-31T23:59:59.500000Z", -1_i64, 500_000_u32},
        {"1969-12-31T23:58:59.000001Z", -61_i64, 1_u32},
        {"1969-12-31T22:58:59.000001Z", -3661_i64, 1_u32},
        {"1969-12-30T22:58:59.000001Z", -90061_i64, 1_u32},

        {"2038-01-19T03:14:07.000000Z", Int32::MAX.to_i64, 0_u32},
        {"2038-01-19T03:14:08.000000Z", Int32::MAX.to_i64 + 1, 0_u32},
        {"1901-12-13T20:45:52.000000Z", Int32::MIN.to_i64, 0_u32},
        {"1901-12-13T20:45:51.000000Z", Int32::MIN.to_i64 - 1, 0_u32},

        {"+292277026596-12-04T15:30:07.000000Z", Int64::MAX, 0_u32},
        {"+292277026596-12-04T15:30:06.000000Z", Int64::MAX - 1, 0_u32},
        {"-292277022657-01-27T08:29:53.000000Z", Int64::MIN + 1, 0_u32},

        {"1900-01-01T00:00:00.000000Z", -2208988800_i64, 0_u32},
        {"1899-12-31T23:59:59.000000Z", -2208988801_i64, 0_u32},
        {"0000-01-01T00:00:00.000000Z", -62167219200_i64, 0_u32},
        {"-0001-12-31T23:59:59.000000Z", -62167219201_i64, 0_u32},

        {"1234-05-06T07:08:09.000000Z", -23215049511_i64, 0_u32},
        {"-1234-05-06T07:08:09.000000Z", -101097651111_i64, 0_u32},
        {"2345-06-07T08:09:01.000000Z", 11847456541_i64, 0_u32},
        {"-2345-06-07T08:09:01.000000Z", -136154620259_i64, 0_u32},
      ]

      cases.each do |expected, secs, micros|
        nanos = micros.to_u32 * 1_000_u32
        dt = DateTime.from_unix(secs: secs, nanos: nanos)
        dt.to_s.should eq(expected), "secs: #{secs}, micros: #{micros}"
      end
    end
  end

  describe SystemTime do
    it "implements FormatTime" do
      SystemTime.new.is_a?(FormatTime).should be_true
    end

    it "writes an ISO 8601 timestamp" do
      io = IO::Memory.new
      SystemTime.new.format_time(io)
      output = io.to_s
      output.should match(%r{^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$})
    end
  end

  describe Uptime do
    it "implements FormatTime" do
      Uptime.new.is_a?(FormatTime).should be_true
    end

    it "writes uptime in seconds.nanos format" do
      io = IO::Memory.new
      uptime = Uptime.new
      sleep(1.millisecond)
      uptime.format_time(io)
      output = io.to_s
      # Format: "   0.XXXXXXXXXs" or "   N.NNNNNNNNNs" (4-wide seconds, dot, 9-wide nanos, s)
      output.should match(/^\s*\d+\.\d{9}s$/)
    end
  end

  describe "free functions" do
    it "time() returns a SystemTime" do
      FmtTime.time.should be_a(SystemTime)
    end

    it "uptime() returns a Uptime" do
      FmtTime.uptime.should be_a(Uptime)
    end
  end
end
