# frozen_string_literal: true

# RagFit patch 0003 (oidc-login-gate, rollout follow-up 2026-10-13): end existing access of OIDC users at the
# rollout of the login gate. GPLv3 §10 modification, see CHANGES-RAGFIT.md.
#
# The gate checks the team claim at login only, and team membership is not stored. Sessions and tokens
# issued before the gate stay valid. This task revokes them for users linked to an OpenID Connect
# provider: browser sessions, API, RSS, iCal and autologin tokens, and OAuth access tokens. Users then have
# to sign in again through the gate; members get in, everyone else is rejected. Local accounts without an
# OIDC link are never touched. RAGFIT_OIDC_KEEP_LOGINS (comma-separated) skips known members.
# Dry run by default (DRY_RUN=0 to revoke). Logs logins and counts only.
module OpenProject::OpenIDConnect
  class RagfitRevokeUngated
    TOKEN_CLASSES = %w[Token::API Token::RSS Token::ICal Token::AutoLogin].freeze

    Result = Struct.new(:selected, :revoked, :dry_run, keyword_init: true)

    attr_reader :provider, :keep_logins, :dry_run, :log

    def initialize(provider: nil, keep_logins: [], dry_run: true, log: ->(line) { Rails.logger.info(line) })
      @provider = provider.to_s.strip.presence
      @keep_logins = keep_logins.map { |l| l.to_s.strip.downcase }.reject(&:empty?)
      @dry_run = dry_run
      @log = log
    end

    def self.from_env(provider_arg, env: ENV, log: ->(line) { puts line })
      new(provider: provider_arg,
          keep_logins: env["RAGFIT_OIDC_KEEP_LOGINS"].to_s.split(","),
          dry_run: env["DRY_RUN"].to_s != "0",
          log:)
    end

    def call
      users = selected_users.to_a
      users.each do |user|
        counts = counts_for(user)
        log.call("#{dry_run ? 'would revoke' : 'revoking'}: #{user.login} (#{counts.map { |k, v| "#{k}=#{v}" }.join(' ')})")
        revoke(user) unless dry_run
      end
      log.call("#{dry_run ? 'dry run' : 'done'}: #{users.size} OIDC user(s)#{dry_run ? ' (set DRY_RUN=0 to revoke)' : ''}")
      Result.new(selected: users.map(&:login), revoked: dry_run ? [] : users.map(&:login), dry_run:)
    end

    private

    def oidc_provider_ids
      scope = ::OpenIDConnect::Provider.all
      scope = scope.where(slug: provider) if provider
      scope.pluck(:id)
    end

    def selected_users
      linked = UserAuthProviderLink.where(auth_provider_id: oidc_provider_ids).select(:principal_id)
      scope = User.not_builtin.where(id: linked)
      scope = scope.where.not("LOWER(login) IN (?)", keep_logins) if keep_logins.any?
      scope.order(:login)
    end

    def token_scopes(user)
      TOKEN_CLASSES.filter_map { |name| name.safe_constantize }.to_h { |klass| [klass, klass.for_user(user)] }
    end

    def oauth_scope(user)
      return nil unless defined?(::Doorkeeper::AccessToken)

      ::Doorkeeper::AccessToken.where(resource_owner_id: user.id, revoked_at: nil)
    end

    def counts_for(user)
      counts = { "sessions" => ::Sessions::UserSession.for_user(user).count }
      token_scopes(user).each { |klass, scope| counts[klass.name.demodulize.downcase] = scope.count }
      counts["oauth"] = oauth_scope(user)&.count.to_i
      counts
    end

    def revoke(user)
      User.transaction do
        ::Sessions::UserSession.for_user(user).delete_all
        token_scopes(user).each_value(&:destroy_all)
        oauth_scope(user)&.update_all(revoked_at: Time.current)
      end
    end
  end
end
