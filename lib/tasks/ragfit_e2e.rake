# frozen_string_literal: true

# RagFit patch 0004 (e2e-user-cleanup): see Ragfit::E2eUserCleanup and README.
namespace :ragfit do
  namespace :e2e do
    desc "Delete E2E test users by login prefix (default e2e-). Dry run unless DRY_RUN=0. " \
         "Optional RAGFIT_E2E_LOGINS=a,b limits to these logins."
    task :delete_users, [:prefix] => :environment do |_task, args|
      result = Ragfit::E2eUserCleanup.from_env(args[:prefix]).call
      exit(1) unless result.success?
    end
  end
end
