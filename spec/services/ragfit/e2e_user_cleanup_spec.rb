# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ragfit::E2eUserCleanup do
  let!(:e2e_a) { create(:user, login: "e2e-plan-a") }
  let!(:e2e_b) { create(:user, login: "E2E-plan-b") }
  let!(:other) { create(:user, login: "alice") }
  let(:lines) { [] }
  let(:log) { ->(line) { lines << line } }

  def run(**)
    described_class.new(log:, **).call
  end

  it "is a dry run by default and deletes nothing" do
    result = run
    expect(result).to be_success
    expect(result.selected).to contain_exactly("e2e-plan-a", "E2E-plan-b")
    expect(result.deleted).to be_empty
    expect(User.where(id: [e2e_a.id, e2e_b.id]).count).to eq(2)
    expect(lines.join("\n")).to include("would delete: e2e-plan-a").and include("DRY_RUN=0")
  end

  it "deletes only users with the prefix when dry_run is false" do
    result = run(prefix: "e2e-plan-", dry_run: false)
    expect(result.deleted).to contain_exactly("e2e-plan-a", "E2E-plan-b")
    expect(User.unscope(where: :status).exists?(e2e_a.id)).to be(false)
    expect(User.unscope(where: :status).exists?(e2e_b.id)).to be(false)
    expect(User.exists?(other.id)).to be(true)
  end

  it "limits deletion to RAGFIT_E2E_LOGINS" do
    result = run(logins: ["e2e-plan-a"], dry_run: false)
    expect(result.deleted).to eq(["e2e-plan-a"])
    expect(User.exists?(e2e_b.id)).to be(true)
  end

  it "refuses logins outside the prefix" do
    result = run(logins: %w[e2e-plan-a alice], dry_run: false)
    expect(result).not_to be_success
    expect(User.exists?(e2e_a.id)).to be(true)
    expect(User.exists?(other.id)).to be(true)
  end

  it "refuses prefixes that are not strict E2E prefixes" do
    ["", "e2e", "e2", "test-", "e2e-%", "e2e_x", "a"].each do |prefix|
      expect(run(prefix:, dry_run: false)).not_to be_success, "prefix #{prefix.inspect} must be refused"
    end
    expect(User.where(id: [e2e_a.id, e2e_b.id, other.id]).count).to eq(3)
  end

  it "refuses the whole run if an admin matches the prefix" do
    create(:admin, login: "e2e-admin")
    result = run(dry_run: false)
    expect(result).not_to be_success
    expect(result.refused).to eq(["e2e-admin"])
    expect(User.exists?(e2e_a.id)).to be(true)
  end

  it "refuses the whole run if a password-login bypass user matches" do
    allow(Users::PasswordLogin).to receive(:bypass?).and_call_original
    allow(Users::PasswordLogin).to receive(:bypass?).with(e2e_b).and_return(true)
    result = run(dry_run: false)
    expect(result).not_to be_success
    expect(result.refused).to eq(["E2E-plan-b"])
    expect(User.exists?(e2e_a.id)).to be(true)
  end

  it "stops with an error and restores the status when the delete job raises" do
    allow(Principals::DeleteJob).to receive(:perform_now).and_call_original
    allow(Principals::DeleteJob).to receive(:perform_now).with(e2e_b).and_raise(ActiveRecord::StatementInvalid, "boom")
    result = run(dry_run: false)
    expect(result).not_to be_success
    expect(result.deleted).to eq(["e2e-plan-a"])
    expect(result.error).to include("deleting E2E-plan-b failed (ActiveRecord::StatementInvalid)")
    expect(User.find(e2e_b.id)).to be_active
  end

  it "reports a silently rolled back deletion as an error" do
    allow(Principals::DeleteJob).to receive(:perform_now)
    result = run(logins: ["e2e-plan-a"], dry_run: false)
    expect(result).not_to be_success
    expect(result.error).to include("deletion rolled back")
    expect(User.find(e2e_a.id)).to be_active
  end

  it "finishes users left marked deleted by an earlier run" do
    e2e_a.update_column(:status, User.statuses[:deleted])
    result = run(logins: ["e2e-plan-a"], dry_run: false)
    expect(result.deleted).to eq(["e2e-plan-a"])
    expect(User.unscope(where: :status).exists?(e2e_a.id)).to be(false)
  end

  it "logs logins only" do
    run
    expect(lines.join("\n")).not_to include(e2e_a.mail)
  end

  describe ".from_env" do
    it "reads DRY_RUN and RAGFIT_E2E_LOGINS" do
      cleanup = described_class.from_env(nil, env: { "DRY_RUN" => "0", "RAGFIT_E2E_LOGINS" => " e2e-plan-a , " }, log:)
      expect(cleanup.dry_run).to be(false)
      expect(cleanup.logins).to eq(["e2e-plan-a"])
      expect(cleanup.prefix).to eq("e2e-")
      expect(described_class.from_env("e2e-x-", env: {}, log:).dry_run).to be(true)
    end
  end

  describe "rake task" do
    before do
      Rails.application.load_tasks unless Rake::Task.task_defined?("ragfit:e2e:delete_users")
      Rake::Task["ragfit:e2e:delete_users"].reenable
    end

    it "runs as a dry run" do
      expect { Rake::Task["ragfit:e2e:delete_users"].invoke("e2e-plan-") }.to output(/would delete: e2e-plan-a/).to_stdout
      expect(User.exists?(e2e_a.id)).to be(true)
    end
  end
end
