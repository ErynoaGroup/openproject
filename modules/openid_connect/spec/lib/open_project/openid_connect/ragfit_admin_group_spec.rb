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

    it "is nil when the variable is blank (whitespace only), so admin stays unchanged" do
      blank = { "RAGFIT_OIDC_SOURCE_ADMIN_GROUP" => "  \t " }
      expect(described_class.admin_for("source", { "groups" => %w[acme:platform-admin] }, env: blank)).to be_nil
      expect(described_class.admin_for("source", { "groups" => [] }, env: blank)).to be_nil
    end

    it "reads the claim from a symbol key :groups like \"groups\"" do
      expect(described_class.admin_for("source", { groups: %w[acme:platform-admin] }, env:)).to be(true)
      expect(described_class.admin_for("source", { groups: %w[acme:dev] }, env:)).to be(false)
    end

    it "ignores entries that are not strings without raising" do
      groups = [nil, 42, :"acme:platform-admin", { "name" => "acme:platform-admin" }, ["acme:platform-admin"]]
      expect(described_class.admin_for("source", { "groups" => groups }, env:)).to be(false)
      expect(described_class.admin_for("source", { "groups" => groups + ["acme:platform-admin"] }, env:)).to be(true)
    end

    it "ignores a bare org name or an empty part (admin unchanged) and logs a warning" do
      allow(Rails.logger).to receive(:warn)
      ["acme", "acme:", ":platform-admin", " : ", "acme: "].each do |value|
        bare = { "RAGFIT_OIDC_SOURCE_ADMIN_GROUP" => value }
        expect(described_class.admin_for("source", { "groups" => %w[acme acme:platform-admin] }, env: bare)).to be_nil
      end
      expect(Rails.logger).to have_received(:warn).with(/RAGFIT_OIDC_SOURCE_ADMIN_GROUP ignored/).exactly(5).times
    end

    it "does not match a group that only shares a prefix" do
      expect(described_class.admin_for("source", { "groups" => %w[acme:platform-admins] }, env:)).to be(false)
    end
  end

  describe "strategy patch" do
    # Production path: OpenProject extends every strategy instance with OmniAuth::FlexibleStrategy.
    def strategy_for(klass = OmniAuth::Strategies::OpenIDConnect, **opts)
      klass.new(nil, name: "source", **opts).tap { |s| s.extend(OmniAuth::FlexibleStrategy) }
    end

    def auth_hash(raw_info)
      OmniAuth::AuthHash.new(extra: { raw_info: })
    end

    before { stub_const("ENV", ENV.to_h.merge(env)) }

    it "is prepended to OmniAuth::FlexibleStrategy" do
      expect(OmniAuth::FlexibleStrategy.ancestors.first).to eq(described_class::StrategyPatch)
    end

    it "adds admin to the user attributes of an extended OIDC strategy, also false" do
      expect(strategy_for.omniauth_hash_to_user_attributes(auth_hash("groups" => %w[acme:dev]))).to include(admin: false)
      expect(strategy_for.omniauth_hash_to_user_attributes(auth_hash("groups" => %w[acme:platform-admin])))
        .to include(admin: true)
    end

    it "keeps the upstream attribute map result" do
      map = ->(_auth) { { login: "jdoe" } }
      result = strategy_for(openproject_attribute_map: map)
                 .omniauth_hash_to_user_attributes(auth_hash("groups" => %w[acme:platform-admin]))
      expect(result).to include(login: "jdoe", admin: true)
    end

    it "adds nothing without a groups claim" do
      expect(strategy_for.omniauth_hash_to_user_attributes(auth_hash({}))).not_to have_key(:admin)
    end

    it "does not touch strategies other than OpenID Connect" do
      other = stub_const("RagfitDummyStrategy", Class.new { include OmniAuth::Strategy })
      strategy = other.new(nil, name: "source").tap { |s| s.extend(OmniAuth::FlexibleStrategy) }
      expect(strategy.omniauth_hash_to_user_attributes(auth_hash("groups" => %w[acme:platform-admin])))
        .not_to have_key(:admin)
    end
  end
end
