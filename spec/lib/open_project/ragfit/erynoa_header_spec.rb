# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenProject::Ragfit::ErynoaHeader do
  describe ".domain" do
    it "drops the first label of the host name" do
      expect(described_class.domain(env: {}, host_name: "plan.example.org")).to eq("example.org")
      expect(described_class.domain(env: {}, host_name: "Plan.Example.org:443")).to eq("example.org")
      expect(described_class.domain(env: {}, host_name: "https://plan.a.example.org/x")).to eq("a.example.org")
    end

    it "returns nil without a usable base domain" do
      ["localhost:3000", "plan.localhost", "", nil, "plan..org", "plan.-x.org"].each do |host|
        expect(described_class.domain(env: {}, host_name: host)).to be_nil, "host #{host.inspect}"
      end
    end

    it "prefers RAGFIT_ERYNOA_DOMAIN and rejects invalid values" do
      expect(described_class.domain(env: { "RAGFIT_ERYNOA_DOMAIN" => " Example.ORG " }, host_name: "x.y.z"))
        .to eq("example.org")
      expect(described_class.domain(env: { "RAGFIT_ERYNOA_DOMAIN" => "bad domain" }, host_name: "plan.example.org"))
        .to be_nil
    end
  end

  describe ".home_url" do
    it "defaults to the source service and accepts an https override only" do
      expect(described_class.home_url("example.org", env: {})).to eq("https://source.example.org/")
      expect(described_class.home_url("example.org", env: { "RAGFIT_ERYNOA_HOME_URL" => "https://home.example.org/" }))
        .to eq("https://home.example.org/")
      ["http://home.example.org/", "javascript:alert(1)", "https://x\"onload"].each do |url|
        expect(described_class.home_url("example.org", env: { "RAGFIT_ERYNOA_HOME_URL" => url }))
          .to eq("https://source.example.org/")
      end
    end
  end

  describe ".theme" do
    it "maps the user's theme" do
      expect(described_class.theme(build_stubbed(:user, preferences: { theme: "dark" }))).to eq("dark")
      expect(described_class.theme(build_stubbed(:user, preferences: { theme: "light" }))).to eq("light")
      expect(described_class.theme(build_stubbed(:user, preferences: { theme: "sync_with_os" }))).to be_nil
    end
  end
end
