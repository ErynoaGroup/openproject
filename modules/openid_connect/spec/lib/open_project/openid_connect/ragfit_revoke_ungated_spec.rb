# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenProject::OpenIDConnect::RagfitRevokeUngated do
  let(:oidc_provider) { create(:oidc_provider, slug: "source") }
  let!(:linked) { create(:user, login: "linked-user") }
  let!(:member) { create(:user, login: "member-user") }
  let!(:local) { create(:admin, login: "breakglass") }
  let(:lines) { [] }
  let(:log) { ->(line) { lines << line } }

  before do
    [linked, member].each_with_index do |user, i|
      UserAuthProviderLink.create!(principal: user, auth_provider: oidc_provider, external_id: "ext-#{i}")
    end
    [linked, member, local].each do |user|
      create(:user_session, user:)
      create(:api_token, user:)
      create(:rss_token, user:)
    end
  end

  def access(user)
    [Sessions::UserSession.for_user(user).count, Token::API.for_user(user).count, Token::RSS.for_user(user).count]
  end

  it "is a dry run by default" do
    result = described_class.new(log:).call
    expect(result.selected).to eq(%w[linked-user member-user])
    expect(result.revoked).to be_empty
    expect(access(linked)).to eq([1, 1, 1])
    expect(lines.join("\n")).to include("would revoke: linked-user").and include("DRY_RUN=0")
  end

  it "revokes sessions and tokens of OIDC-linked users only" do
    result = described_class.new(dry_run: false, log:).call
    expect(result.revoked).to eq(%w[linked-user member-user])
    expect(access(linked)).to eq([0, 0, 0])
    expect(access(member)).to eq([0, 0, 0])
    expect(access(local)).to eq([1, 1, 1])
    expect(User.find(linked.id)).to be_active
  end

  it "skips RAGFIT_OIDC_KEEP_LOGINS and other providers" do
    cleanup = described_class.from_env("source", env: { "DRY_RUN" => "0", "RAGFIT_OIDC_KEEP_LOGINS" => " Member-User " },
                                                 log:)
    expect(cleanup.call.revoked).to eq(%w[linked-user])
    expect(access(member)).to eq([1, 1, 1])
  end

  it "fails for an unknown provider slug" do
    result = described_class.new(provider: "other", dry_run: false, log:).call
    expect(result).not_to be_success
    expect(result.error).to include("no OpenID Connect provider with slug 'other'")
    expect(access(linked)).to eq([1, 1, 1])
  end

  it "warns about RAGFIT_OIDC_KEEP_LOGINS entries without a user" do
    result = described_class.new(keep_logins: %w[member-user nobody-here], log:).call
    expect(result).to be_success
    expect(lines).to include("warning: RAGFIT_OIDC_KEEP_LOGINS entry 'nobody-here' matches no user")
    expect(lines.join("\n")).not_to include("entry 'member-user'")
  end

  it "stops with an error when revoking fails" do
    allow(Sessions::UserSession).to receive(:for_user).and_call_original
    allow(Sessions::UserSession).to receive(:for_user).with(member).and_raise(ActiveRecord::StatementInvalid, "boom")
    result = described_class.new(dry_run: false, log:).call
    expect(result).not_to be_success
    expect(result.revoked).to eq(%w[linked-user])
    expect(result.error).to include("revoking member-user failed")
  end

  it "exits non-zero from the rake task on error" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("ragfit:oidc:revoke_ungated")
    Rake::Task["ragfit:oidc:revoke_ungated"].reenable
    expect do
      expect { Rake::Task["ragfit:oidc:revoke_ungated"].invoke("other") }
        .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end.to output(/no OpenID Connect provider/).to_stdout
  end
end

RSpec.describe OpenProject::OpenIDConnect::RagfitLoginGate, "logging of a rejected login" do
  let(:io) { StringIO.new }
  let(:logger) { ActiveSupport::Logger.new(io).tap { |l| l.level = Logger::DEBUG } }
  let(:strategy) { double(name: "source") }
  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      "provider" => "source", "uid" => "subject-123",
      "info" => { "name" => "Out Sider", "email" => "outsider-mail-marker" },
      "extra" => { "raw_info" => { "preferred_username" => "outsider", "groups" => %w[OtherOrg:team],
                                   "email" => "outsider-mail-marker" } }
    )
  end

  before do
    stub_const("ENV", ENV.to_h.merge("RAGFIT_OIDC_SOURCE_LOGIN_GROUPS" => "ErynoaGroup:plan-user"))
    allow(Rails).to receive(:logger).and_return(logger)
  end

  it "logs provider and login only and returns the rejection" do
    result = Authentication::OmniauthService.new(strategy:, auth_hash:, controller: double).call
    expect(result).to be_failure
    expect(result.message).to eq(I18n.t("user.authorization_rejected"))
    expect(io.string).to include("rejected for 'outsider'")
    expect(io.string).not_to include("outsider-mail-marker")
    expect(io.string).not_to include("Returning from omniauth")
    expect(io.string).not_to include("subject-123")
  end

  it "keeps upstream handling for approved logins" do
    allowed = auth_hash.deep_dup
    allowed["extra"]["raw_info"]["groups"] = %w[ErynoaGroup:plan-user]
    expect(described_class.rejects?(allowed)).to be(false)
    expect(described_class.rejects?(auth_hash)).to be(true)
  end
end
