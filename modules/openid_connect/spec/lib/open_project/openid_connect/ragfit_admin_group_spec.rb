# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenProject::OpenIDConnect::RagfitAdminGroup do
  let(:env) { { "RAGFIT_OIDC_SOURCE_ADMIN_GROUP" => "acme:platform-admin" } }

  describe ".admin_for" do
    it "is true when the group is in the claim (case-insensitive)" do
      expect(described_class.admin_for("source", { "groups" => %w[acme Acme:Platform-Admin] }, env:)).to be(true)
    end

    it "is false when the claim is present without the group, so admin is revoked" do
      expect(described_class.admin_for("source", { "groups" => %w[acme acme:dev] }, env:)).to be(false)
      expect(described_class.admin_for("source", { "groups" => [] }, env:)).to be(false)
    end

    it "is nil without a groups claim" do
      expect(described_class.admin_for("source", {}, env:)).to be_nil
      expect(described_class.admin_for("source", { "groups" => "acme:platform-admin" }, env:)).to be_nil
    end

    it "is nil when the variable is not set for this provider" do
      expect(described_class.admin_for("other", { "groups" => %w[acme:platform-admin] }, env:)).to be_nil
      expect(described_class.admin_for("source", { "groups" => %w[acme:platform-admin] }, env: {})).to be_nil
    end

    it "does not match a group that only shares a prefix" do
      expect(described_class.admin_for("source", { "groups" => %w[acme:platform-admins] }, env:)).to be(false)
    end
  end

  describe "strategy patch" do
    it "is prepended to the OpenID Connect strategy" do
      expect(OmniAuth::Strategies::OpenIDConnect.ancestors).to include(described_class::StrategyPatch)
    end

    it "adds admin to the user attributes, also false" do
      strategy = OmniAuth::Strategies::OpenIDConnect.new(nil, name: "source")
      hash = OmniAuth::AuthHash.new(extra: { raw_info: { "groups" => %w[acme:dev] } })
      stub_const("ENV", ENV.to_h.merge(env))
      expect(strategy.omniauth_hash_to_user_attributes(hash)).to include(admin: false)
    end

    it "adds nothing without a groups claim" do
      strategy = OmniAuth::Strategies::OpenIDConnect.new(nil, name: "source")
      stub_const("ENV", ENV.to_h.merge(env))
      expect(strategy.omniauth_hash_to_user_attributes(OmniAuth::AuthHash.new(extra: { raw_info: {} }))).not_to have_key(:admin)
    end
  end
end
