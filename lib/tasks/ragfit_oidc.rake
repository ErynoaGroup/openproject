# frozen_string_literal: true

# RagFit patch 0003 (oidc-login-gate): see OpenProject::OpenIDConnect::RagfitRevokeUngated and README (login gate rollout).
namespace :ragfit do
  namespace :oidc do
    desc "Revoke sessions and tokens of users linked to an OpenID Connect provider (optional provider slug). " \
         "Dry run unless DRY_RUN=0. RAGFIT_OIDC_KEEP_LOGINS=a,b skips these logins."
    task :revoke_ungated, [:provider] => :environment do |_task, args|
      OpenProject::OpenIDConnect::RagfitRevokeUngated.from_env(args[:provider]).call
    end
  end
end
