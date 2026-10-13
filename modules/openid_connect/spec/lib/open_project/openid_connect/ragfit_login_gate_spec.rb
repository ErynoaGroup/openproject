# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenProject::OpenIDConnect::RagfitLoginGate do
  let(:env) do
    {
      "RAGFIT_OIDC_SOURCE_LOGIN_GROUPS" => " ErynoaGroup:plan-user , ErynoaGroup:qa ",
      "RAGFIT_OIDC_SOURCE_ADMIN_GROUP" => "ErynoaGroup:platform-admin"
    }
  end

  def auth_hash(raw_info, provider: "source")
    OmniAuth::AuthHash.new(provider:, uid: "u1", info: { name: "n", email: "e" }, extra: { raw_info: })
  end

  def decide(hash, env: self.env)
    store = OpenProject::OmniAuth::Authorization::DecisionStore.new
    described_class.authorize(store, hash, env:)
    store.decision
  end

  before { allow(Rails.logger).to receive(:warn) }

  it "rejects a login without an allowed team" do
    expect(decide(auth_hash("groups" => %w[ErynoaGroup ErynoaGroup:dev]))).to be_reject
  end

  it "approves a login with an allowed team (case-insensitive)" do
    expect(decide(auth_hash("groups" => %w[ErynoaGroup erynoagroup:PLAN-USER]))).to be_approve
    expect(decide(auth_hash("groups" => %w[ErynoaGroup:qa]))).to be_approve
  end

  it "approves a login with only the admin group" do
    expect(decide(auth_hash("groups" => %w[ErynoaGroup:platform-admin]))).to be_approve
  end

  it "rejects when the groups claim is missing or not an array (fail closed)" do
    expect(decide(auth_hash({}))).to be_reject
    expect(decide(auth_hash("groups" => "ErynoaGroup:plan-user"))).to be_reject
  end

  it "matches claim entries exactly: no trimming, no prefix or substring match" do
    expect(decide(auth_hash("groups" => [" ErynoaGroup:plan-user"]))).to be_reject
    expect(decide(auth_hash("groups" => ["ErynoaGroup:plan-user "]))).to be_reject
    expect(decide(auth_hash("groups" => ["ErynoaGroup:plan-user-x"]))).to be_reject
    expect(decide(auth_hash("groups" => ["ErynoaGroup:plan"]))).to be_reject
  end

  it "ignores non-string claim entries" do
    expect(decide(auth_hash("groups" => [nil, 1, :"ErynoaGroup:plan-user", ["ErynoaGroup:plan-user"]]))).to be_reject
  end

  it "approves everything when the variable is not set (backward compatible)" do
    expect(decide(auth_hash({}), env: {})).to be_approve
    expect(decide(auth_hash("groups" => %w[ErynoaGroup]), env: { "RAGFIT_OIDC_SOURCE_LOGIN_GROUPS" => "  " })).to be_approve
  end

  it "ignores invalid entries with a warning and keeps the valid ones" do
    gate = { "RAGFIT_OIDC_SOURCE_LOGIN_GROUPS" => "ErynoaGroup, :x, y:, ErynoaGroup:plan-user, a:b:c" }
    expect(described_class.allowed_groups("source", env: gate)).to eq(["erynoagroup:plan-user"])
    expect(decide(auth_hash("groups" => %w[ErynoaGroup]), env: gate)).to be_reject
    expect(decide(auth_hash("groups" => %w[ErynoaGroup:plan-user]), env: gate)).to be_approve
    expect(Rails.logger).to have_received(:warn).with(/LOGIN_GROUPS entry ignored/).at_least(4).times
  end

  it "is not active when only invalid entries are set" do
    expect(decide(auth_hash({}), env: { "RAGFIT_OIDC_SOURCE_LOGIN_GROUPS" => "ErynoaGroup" })).to be_approve
  end

  it "does not gate other providers" do
    expect(decide(auth_hash({}, provider: "other"))).to be_approve
  end

  it "does not gate auth providers that are not OpenID Connect" do
    allow(AuthProvider).to receive(:find_by).with(slug: "source").and_return(AuthProvider.new)
    expect(decide(auth_hash({}))).to be_approve
  end

  it "logs the rejection with the login only" do
    decide(auth_hash("groups" => %w[ErynoaGroup], "preferred_username" => "jdoe", "email" => "x"))
    expect(Rails.logger).to have_received(:warn).with(/rejected for 'jdoe'/)
  end

  it "is registered as an OmniAuth authorization callback" do
    stub_const("ENV", ENV.to_h.merge(env))
    expect(OpenProject::OmniAuth::Authorization.authorized?(auth_hash("groups" => %w[ErynoaGroup]))).to be_reject
    expect(OpenProject::OmniAuth::Authorization.authorized?(auth_hash("groups" => %w[ErynoaGroup:plan-user])))
      .to be_approve
  end
end
