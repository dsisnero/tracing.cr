require "./spec_helper"

{% if flag?(:trace_max_off) %}
  describe "trace_max_off" do
    it "strips event field expressions at compile time" do
      evaluated = false
      info!("ignored", value: (evaluated = true))
      evaluated.should be_false
    end

    it "strips span names and fields while preserving the span API" do
      evaluated = false
      span = info_span!((evaluated = true).to_s, value: (evaluated = true))

      evaluated.should be_false
      span.disabled?.should be_true
      span.in_scope { 42 }.should eq(42)
    end
  end
{% end %}
