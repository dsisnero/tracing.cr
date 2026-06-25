require "./spec_helper"

# Ported from vendor/tracing/tracing-subscriber/src/filter/targets.rs tests.
#
# Upstream asserts on the private `DirectiveSet::into_vec()` ordering; here we
# assert on the observable surface (`iter`, `default_level`, `would_enable`,
# `to_s` round-trip), which captures the same behavior without coupling to the
# internal sort order.
module TargetsParseSpec
  alias L = Tracing::Level
  alias LF = Tracing::LevelFilter

  describe "Targets.parse (ported from filter/targets.rs)" do
    it "parses target=level pairs (parse_ralith)" do
      t = Tracing::Targets.parse("common=info,server=debug")
      t.iter.sort_by(&.[0]).should eq([
        {"common", LF.info},
        {"server", LF.debug},
      ])
    end

    it "parses uppercase level names (parse_ralith_uc)" do
      t = Tracing::Targets.parse("common=INFO,server=DEBUG")
      t.iter.sort_by(&.[0]).should eq([
        {"common", LF.info},
        {"server", LF.debug},
      ])
    end

    it "parses mixed-case level names (parse_ralith_mixed)" do
      t = Tracing::Targets.parse("common=iNfo,server=dEbUg")
      t.iter.sort_by(&.[0]).should eq([
        {"common", LF.info},
        {"server", LF.debug},
      ])
    end

    it "treats a bare target as TRACE and parses off (expect_parse_valid)" do
      t = Tracing::Targets.parse("crate1::mod1=error,crate1::mod2,crate2=debug,crate3=off")
      t.iter.sort_by(&.[0]).should eq([
        {"crate1::mod1", LF.error},
        {"crate1::mod2", LF.trace},
        {"crate2", LF.debug},
        {"crate3", LF.off},
      ])
      t.default_level.should be_nil
    end

    it "parses named level directives (parse_level_directives)" do
      t = Tracing::Targets.parse(
        "crate1::mod1=error,crate1::mod2=warn,crate1::mod2::mod3=info," \
        "crate2=debug,crate3=trace,crate3::mod2::mod1=off")
      t.iter.sort_by(&.[0]).should eq([
        {"crate1::mod1", LF.error},
        {"crate1::mod2", LF.warn},
        {"crate1::mod2::mod3", LF.info},
        {"crate2", LF.debug},
        {"crate3", LF.trace},
        {"crate3::mod2::mod1", LF.off},
      ])
    end

    it "parses uppercase level directives (parse_uppercase_level_directives)" do
      t = Tracing::Targets.parse(
        "crate1::mod1=ERROR,crate1::mod2=WARN,crate1::mod2::mod3=INFO," \
        "crate2=DEBUG,crate3=TRACE,crate3::mod2::mod1=OFF")
      t.iter.sort_by(&.[0]).should eq([
        {"crate1::mod1", LF.error},
        {"crate1::mod2", LF.warn},
        {"crate1::mod2::mod3", LF.info},
        {"crate2", LF.debug},
        {"crate3", LF.trace},
        {"crate3::mod2::mod1", LF.off},
      ])
    end

    it "parses numeric level directives 0-5 (parse_numeric_level_directives)" do
      t = Tracing::Targets.parse(
        "crate1::mod1=1,crate1::mod2=2,crate1::mod2::mod3=3," \
        "crate2=4,crate3=5,crate3::mod2::mod1=0")
      t.iter.sort_by(&.[0]).should eq([
        {"crate1::mod1", LF.error},
        {"crate1::mod2", LF.warn},
        {"crate1::mod2::mod3", LF.info},
        {"crate2", LF.debug},
        {"crate3", LF.trace},
        {"crate3::mod2::mod1", LF.off},
      ])
    end
  end

  describe "Targets#default_level (targets_default_level)" do
    it "is nil when no bare level is given" do
      t = Tracing::Targets.parse("crate1::mod1=error,crate1::mod2,crate2=debug,crate3=off")
      t.default_level.should be_nil
    end

    it "reflects an explicit with_default" do
      t = Tracing::Targets.parse("crate1::mod1=error").with_default(LF.off)
      t.default_level.should eq(LF.off)
    end

    it "uses the last with_default when set repeatedly" do
      t = Tracing::Targets.parse("crate1::mod1=error")
        .with_default(LF.off)
        .with_default(LF.info)
      t.default_level.should eq(LF.info)
    end

    it "parses a bare level as the default level" do
      t = Tracing::Targets.parse("info")
      t.default_level.should eq(LF.info)
      t.iter.empty?.should be_true
    end
  end

  describe "Targets#iter (targets_iter)" do
    it "yields target-level pairs excluding the default" do
      t = Tracing::Targets.parse("crate1::mod1=error,crate1::mod2,crate2=debug,crate3=off")
        .with_default(LF.warn)
      t.iter.sort_by(&.[0]).should eq([
        {"crate1::mod1", LF.error},
        {"crate1::mod2", LF.trace},
        {"crate2", LF.debug},
        {"crate3", LF.off},
      ])
    end
  end

  describe "Targets#would_enable" do
    it "matches the most specific target prefix" do
      t = Tracing::Targets.new
        .with_target("my_crate", L::INFO)
        .with_target("my_crate::interesting_module", L::DEBUG)
      t.would_enable("my_crate", L::INFO).should be_true
      t.would_enable("my_crate::interesting_module", L::TRACE).should be_false
    end
  end

  describe "Targets#to_s (display_roundtrips)" do
    it "round-trips through parse" do
      [
        "crate1::mod1=error,crate1::mod2,crate2=debug,crate3=off",
        "crate1::mod1=ERROR,crate1::mod2=WARN,crate1::mod2::mod3=INFO," \
        "crate2=DEBUG,crate3=TRACE,crate3::mod2::mod1=OFF",
        "crate1::mod1,crate1::mod2,info",
        "crate1",
        "info",
      ].each do |directive_string|
        filter = Tracing::Targets.parse(directive_string)
        reparsed = Tracing::Targets.parse(filter.to_s)
        reparsed.should eq(filter)
      end
    end

    it "emits lowercase target=level" do
      t = Tracing::Targets.new.with_target("my_crate", L::INFO)
      t.to_s.should eq("my_crate=info")
    end
  end
end
