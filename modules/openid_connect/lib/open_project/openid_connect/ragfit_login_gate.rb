# frozen_string_literal: true

# RagFit patch 0003 (oidc-login-gate, 2026-10-13): allow an OIDC login only for members of listed teams.
# GPLv3 §10 modification, see CHANGES-RAGFIT.md.
#
# Rule: OIDC logins are authorized only on a full team claim "<org>:<team>". For every OpenID Connect
# provider, RAGFIT_OIDC_<PROVIDER>_LOGIN_GROUPS (comma-separated team claims, e.g. "ErynoaGroup:plan-user")
# lists the teams that may sign in; the provider's RAGFIT_OIDC_<PROVIDER>_ADMIN_GROUP counts as well.
# A login is approved only if the userinfo "groups" claim contains one of them. Otherwise it is rejected
# before any user is looked up, created or updated (upstream OmniAuth authorization callback, checked in
# Authentication::OmniauthAuthHashContract). Fail closed: a missing "groups" claim, or a provider without
# a valid LOGIN_GROUPS value, rejects every login of that provider (error logged at boot for providers
# configured through OPENPROJECT_OPENID__CONNECT_<NAME>_* variables).
#
# Matching: claim entries must be strings and equal a team exactly, case-insensitive (Gitea lower-cases
# team names). Claim entries are NOT trimmed: " ErynoaGroup:plan-user" or "ErynoaGroup:plan-user-x" do not
# match. Only the variable's own entries are trimmed when parsed; entries that are not "<org>:<team>"
# with non-empty parts are ignored with a warning. Only OpenID Connect providers are gated; other auth
# providers are approved unchanged.
#
# Password login: users linked to an OpenID Connect provider (user_auth_provider_links) cannot sign in
# with a password or API basic auth (Users::PasswordLogin.allowed? returns false), so the gate cannot be
# bypassed. Local accounts without such a link (e.g. a break-glass admin) keep password login.
#
# Logging (2026-10-13 follow-up): a rejected login is logged as provider and login only. For a gate
# rejection Authentication::OmniauthService#call returns the failure itself, so upstream does not log the
# full auth hash (inspect_response) or the uid line for it. Other failures keep the upstream logging.
#
# Non-OIDC providers (SAML, other OmniAuth strategies) are approved unchanged: this deployment signs in
# through OpenID Connect only, those providers carry no team claim to check, and gating them would need a
# provider-specific claim mapping. Enable such a provider only together with its own authorization.
module OpenProject::OpenIDConnect::RagfitLoginGate
  module_function

  def env_name(provider_name)
    "RAGFIT_OIDC_#{provider_name.to_s.upcase.gsub(/[^A-Z0-9]/, '_')}_LOGIN_GROUPS"
  end

  def log_warn(message)
    defined?(Rails) && Rails.logger ? Rails.logger.warn(message) : warn(message)
  end

  def team_claim?(entry)
    org, team = entry.split(":", 2)
    !org.to_s.strip.empty? && !team.to_s.strip.empty? && !team.include?(":")
  end

  # Allowed teams for a provider (downcased); empty when nothing valid is configured (= reject all).
  def allowed_groups(provider_name, env: ENV)
    raw = env[env_name(provider_name)].to_s
    return [] if raw.strip.empty?

    allowed = raw.split(",").map(&:strip).reject(&:empty?).select do |entry|
      team_claim?(entry).tap do |ok|
        log_warn("RagFit: #{env_name(provider_name)} entry ignored, expected '<org>:<team>'") unless ok
      end
    end
    return [] if allowed.empty?

    admin = env[OpenProject::OpenIDConnect::RagfitAdminGroup.env_name(provider_name)].to_s.strip
    allowed << admin if !admin.empty? && team_claim?(admin)
    allowed.map(&:downcase).uniq
  end

  # true: approve, false: reject.
  def allowed?(provider_name, raw_info, env: ENV)
    allowed = allowed_groups(provider_name, env:)
    return false if allowed.empty?

    groups = raw_info.respond_to?(:[]) ? (raw_info["groups"] || raw_info[:groups]) : nil
    return false unless groups.is_a?(Array)

    groups.any? { |g| g.is_a?(String) && allowed.include?(g.downcase) }
  end

  def oidc_provider?(slug)
    provider = ::AuthProvider.find_by(slug: slug.to_s)
    provider.nil? || provider.is_a?(::OpenIDConnect::Provider)
  rescue StandardError
    true
  end

  # true if the gate rejects this auth hash (no logging, no side effects).
  def rejects?(auth_hash, env: ENV)
    provider = auth_hash.respond_to?(:provider) ? auth_hash.provider.to_s : ""
    return false if provider.empty? || !oidc_provider?(provider)

    raw_info = auth_hash.dig("extra", "raw_info") || {}
    !allowed?(provider, raw_info, env:)
  end

  # Upstream extension point: OpenProject::OmniAuth::Authorization callback.
  def authorize(decision, auth_hash, env: ENV)
    provider = auth_hash&.provider.to_s
    # Non-OIDC providers stay ungated (see header).
    return decision.approve if provider.empty? || !oidc_provider?(provider)

    raw_info = auth_hash.dig("extra", "raw_info") || {}
    return decision.approve if allowed?(provider, raw_info, env:)

    login = raw_info["preferred_username"] || raw_info[:preferred_username] || auth_hash["uid"]
    reason = allowed_groups(provider, env:).empty? ? "no valid #{env_name(provider)}" : "no allowed team"
    log_warn("RagFit login gate: OIDC login via '#{provider}' rejected for '#{login}' (#{reason})")
    decision.reject(I18n.t("user.authorization_rejected"))
  end

  def register!
    return if @registered

    OpenProject::OmniAuth::Authorization.authorize_user do |decision, auth_hash|
      authorize(decision, auth_hash)
    end
    ::Users::PasswordLogin.singleton_class.prepend(PasswordLoginPatch)
    ::Authentication::OmniauthService.prepend(OmniauthServicePatch)
    @registered = true
    check_env_providers!
  end

  # Providers configured through OPENPROJECT_OPENID__CONNECT_<NAME>_* (env seed), by slug.
  def env_providers(env: ENV)
    env.keys.filter_map { |k| k[/\AOPENPROJECT_OPENID__CONNECT_([A-Z0-9]+)_/, 1] }.uniq.map(&:downcase)
  end

  # Boot check: an OIDC provider without a valid LOGIN_GROUPS value rejects every login.
  def check_env_providers!(env: ENV)
    env_providers(env:).each do |slug|
      next unless allowed_groups(slug, env:).empty?

      message = "RagFit login gate: #{env_name(slug)} empty or invalid, every OIDC login via '#{slug}' is rejected"
      defined?(Rails) && Rails.logger ? Rails.logger.error(message) : warn(message)
    end
  end

  # True if the user is linked to an OpenID Connect provider.
  def oidc_linked?(user)
    return false unless user.respond_to?(:user_auth_provider_links)

    user.user_auth_provider_links.any? { |link| link.auth_provider.is_a?(::OpenIDConnect::Provider) }
  end

  # Gate rejection: validate (the callback logs provider and login) and return the failure without the
  # upstream error logging, which would write the full auth hash (claims, e-mail, groups) to the log.
  module OmniauthServicePatch
    def call(additional_user_params = nil)
      return super unless OpenProject::OpenIDConnect::RagfitLoginGate.rejects?(auth_hash)

      contract.validate
      ServiceResult.failure(errors: contract.errors)
    end
  end

  module PasswordLoginPatch
    def allowed?(user)
      return false if user.present? && OpenProject::OpenIDConnect::RagfitLoginGate.oidc_linked?(user)

      super
    end
  end
end
