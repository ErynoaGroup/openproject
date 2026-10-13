# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenProject::OpenIDConnect::RagfitLoginGate do
  let(:env) do
    {
      "RAGFIT_OIDC_SOURCE_LOGIN_GROUPS" => " ErynoaGroup:plan-user , ErynoaGroup:qa ",
      "RAGFIT_OIDC_SOURCE_ADMIN_GROUP" => "ErynoaGroup:platform-admin"
    }
  end

  def gate_hash(raw_info, provider = "source")
    OmniAuth::AuthHash.new("provider" => provider, "uid" => "u1", "extra" => { "raw_info" => raw_info })
  end

  def decide(hash, env: self.env)
    store = OpenProject::OmniAuth::Authorization::DecisionStore.new
    described_class.authorize(store, hash, env:)
    store.decision
  end

  before { allow(Rails.logger).to receive(:warn) }

  it "rejects a login without an allowed team" do
    expect(decide(gate_hash("groups" => %w[ErynoaGroup ErynoaGroup:dev]))).to be_reject
  end

  it "approves a login with an allowed team (case-insensitive)" do
    expect(decide(gate_hash("groups" => %w[ErynoaGroup erynoagroup:PLAN-USER]))).to be_approve
    expect(decide(gate_hash("groups" => %w[ErynoaGroup:qa]))).to be_approve
  end

  it "approves a login with only the admin group" do
    expect(decide(gate_hash("groups" => %w[ErynoaGroup:platform-admin]))).to be_approve
  end

  it "rejects when the groups claim is missing or not an array (fail closed)" do
    expect(decide(gate_hash({}))).to be_reject
    expect(decide(gate_hash("groups" => "ErynoaGroup:plan-user"))).to be_reject
  end

  it "matches claim entries exactly: no trimming, no prefix or substring match" do
    expect(decide(gate_hash("groups" => [" ErynoaGroup:plan-user"]))).to be_reject
    expect(decide(gate_hash("groups" => ["ErynoaGroup:plan-user "]))).to be_reject
    expect(decide(gate_hash("groups" => ["ErynoaGroup:plan-user-x"]))).to be_reject
    expect(decide(gate_hash("groups" => ["ErynoaGroup:plan"]))).to be_reject
  end

  it "ignores non-string claim entries" do
    expect(decide(gate_hash("groups" => [nil, 1, :"ErynoaGroup:plan-user", ["ErynoaGroup:plan-user"]]))).to be_reject
  end

  it "rejects every login when the variable is not set or blank (fail closed)" do
    expect(decide(gate_hash("groups" => %w[ErynoaGroup:plan-user]), env: {})).to be_reject
    expect(decide(gate_hash("groups" => %w[ErynoaGroup:plan-user]), env: { "RAGFIT_OIDC_SOURCE_LOGIN_GROUPS" => "  " }))
      .to be_reject
  end

  it "does not let the admin group alone open the gate without LOGIN_GROUPS" do
    admin_only = { "RAGFIT_OIDC_SOURCE_ADMIN_GROUP" => "ErynoaGroup:platform-admin" }
    expect(decide(gate_hash("groups" => %w[ErynoaGroup:platform-admin]), env: admin_only)).to be_reject
  end

  it "ignores invalid entries with a warning and keeps the valid ones" do
    gate = { "RAGFIT_OIDC_SOURCE_LOGIN_GROUPS" => "ErynoaGroup, :x, y:, ErynoaGroup:plan-user, a:b:c" }
    expect(described_class.allowed_groups("source", env: gate)).to eq(["erynoagroup:plan-user"])
    expect(decide(gate_hash("groups" => %w[ErynoaGroup]), env: gate)).to be_reject
    expect(decide(gate_hash("groups" => %w[ErynoaGroup:plan-user]), env: gate)).to be_approve
    expect(Rails.logger).to have_received(:warn).with(/LOGIN_GROUPS entry ignored/).at_least(4).times
  end

  it "rejects every login when only invalid entries are set" do
    expect(decide(gate_hash("groups" => %w[ErynoaGroup]), env: { "RAGFIT_OIDC_SOURCE_LOGIN_GROUPS" => "ErynoaGroup" }))
      .to be_reject
  end

  it "rejects an OIDC provider without its own LOGIN_GROUPS" do
    expect(decide(gate_hash({ "groups" => %w[ErynoaGroup:plan-user] }, "other"))).to be_reject
  end

  it "logs an error at boot for env-configured providers without valid LOGIN_GROUPS" do
    allow(Rails.logger).to receive(:error)
    boot_env = {
      "OPENPROJECT_OPENID__CONNECT_SOURCE_IDENTIFIER" => "x",
      "OPENPROJECT_OPENID__CONNECT_OTHER_IDENTIFIER" => "y",
      "RAGFIT_OIDC_SOURCE_LOGIN_GROUPS" => "ErynoaGroup:plan-user"
    }
    described_class.check_env_providers!(env: boot_env)
    expect(Rails.logger).to have_received(:error).with(/RAGFIT_OIDC_OTHER_LOGIN_GROUPS empty or invalid/).once
    expect(Rails.logger).not_to have_received(:error).with(/RAGFIT_OIDC_SOURCE_LOGIN_GROUPS/)
  end

  it "does not gate auth providers that are not OpenID Connect" do
    allow(AuthProvider).to receive(:find_by).with(slug: "source").and_return(AuthProvider.new)
    expect(decide(gate_hash({}))).to be_approve
  end

  it "logs the rejection with the login only" do
    decide(gate_hash("groups" => %w[ErynoaGroup], "preferred_username" => "jdoe", "email" => "x"))
    expect(Rails.logger).to have_received(:warn).with(/rejected for 'jdoe'/)
  end

  it "is registered as an OmniAuth authorization callback" do
    stub_const("ENV", ENV.to_h.merge(env))
    expect(OpenProject::OmniAuth::Authorization.authorized?(gate_hash("groups" => %w[ErynoaGroup]))).to be_reject
    expect(OpenProject::OmniAuth::Authorization.authorized?(gate_hash("groups" => %w[ErynoaGroup:plan-user])))
      .to be_approve
  end

  describe "password login" do
    let(:oidc_provider) { create(:oidc_provider, slug: "source") }
    let(:linked) { create(:user, password: "adminADMIN!1", password_confirmation: "adminADMIN!1") }
    let(:local) { create(:user, password: "adminADMIN!1", password_confirmation: "adminADMIN!1") }

    before do
      UserAuthProviderLink.create!(principal: linked, auth_provider: oidc_provider, external_id: "ext-1")
      linked.reload
    end

    it "is refused for a user linked to an OpenID Connect provider" do
      expect(Users::PasswordLogin.allowed?(linked)).to be(false)
      expect(linked.check_password?("adminADMIN!1")).to be(false)
      expect(User.try_to_login(linked.login, "adminADMIN!1")).to be_nil
    end

    it "stays allowed for a local account without an OIDC link" do
      expect(Users::PasswordLogin.allowed?(local)).to be(true)
      expect(User.try_to_login(local.login, "adminADMIN!1")).to eq(local)
    end
  end
end
