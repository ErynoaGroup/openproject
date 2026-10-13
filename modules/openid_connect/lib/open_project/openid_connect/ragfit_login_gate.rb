# frozen_string_literal: true

# RagFit patch 0003 (oidc-login-gate, 2026-10-13): allow an OIDC login only for members of listed teams.
# GPLv3 §10 modification, see CHANGES-RAGFIT.md.
#
# Binding rule (2026-10-13): Source OIDC consumers authorize only on a full team claim "<org>:<team>",
# also at login. With RAGFIT_OIDC_<PROVIDER>_LOGIN_GROUPS set (comma-separated team claims, e.g.
# "ErynoaGroup:plan-user"), a login through that provider is approved only if the userinfo "groups" claim
# contains at least one listed team or the provider's RAGFIT_OIDC_<PROVIDER>_ADMIN_GROUP. Otherwise it is
# rejected before any user is looked up, created or updated (upstream OmniAuth authorization callback,
# checked in Authentication::OmniauthAuthHashContract). A missing "groups" claim is rejected (fail closed).
#
# Matching: claim entries must be strings and equal a team exactly, case-insensitive (Gitea lower-cases
# team names). Claim entries are NOT trimmed: " ErynoaGroup:plan-user" or "ErynoaGroup:plan-user-x" do not
# match. Only the variable's own entries are trimmed when parsed; entries that are not "<org>:<team>"
# with non-empty parts are ignored with a warning. Without the variable (or with no valid entry) the
# provider behaves as upstream; a warning is logged once at boot if no provider has a login gate.
# Only OpenID Connect providers are gated; other auth providers are approved unchanged.
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

  # Allowed teams for a provider (downcased), or nil when the gate is not active.
  def allowed_groups(provider_name, env: ENV)
    raw = env[env_name(provider_name)].to_s
    return nil if raw.strip.empty?

    allowed = raw.split(",").map(&:strip).reject(&:empty?).select do |entry|
      team_claim?(entry).tap do |ok|
        log_warn("RagFit: #{env_name(provider_name)} entry ignored, expected '<org>:<team>'") unless ok
      end
    end
    return nil if allowed.empty?

    admin = env[OpenProject::OpenIDConnect::RagfitAdminGroup.env_name(provider_name)].to_s.strip
    allowed << admin if !admin.empty? && team_claim?(admin)
    allowed.map(&:downcase).uniq
  end

  # true: approve, false: reject, nil: gate not active for this provider.
  def allowed?(provider_name, raw_info, env: ENV)
    allowed = allowed_groups(provider_name, env:)
    return nil if allowed.nil?

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

  # Upstream extension point: OpenProject::OmniAuth::Authorization callback.
  def authorize(decision, auth_hash, env: ENV)
    provider = auth_hash&.provider.to_s
    return decision.approve if provider.empty? || !oidc_provider?(provider)

    raw_info = auth_hash.dig("extra", "raw_info") || {}
    result = allowed?(provider, raw_info, env:)
    return decision.approve unless result == false

    login = raw_info["preferred_username"] || raw_info[:preferred_username] || auth_hash["uid"]
    log_warn("RagFit login gate: OIDC login via '#{provider}' rejected for '#{login}' (no allowed team)")
    decision.reject(I18n.t("user.authorization_rejected"))
  end

  def register!
    return if @registered

    OpenProject::OmniAuth::Authorization.authorize_user do |decision, auth_hash|
      authorize(decision, auth_hash)
    end
    @registered = true
    warn_if_unset!
  end

  def warn_if_unset!(env: ENV)
    return if env.keys.any? { |k| k.start_with?("RAGFIT_OIDC_") && k.end_with?("_LOGIN_GROUPS") && !env[k].to_s.strip.empty? }

    log_warn("RagFit login gate: no RAGFIT_OIDC_<PROVIDER>_LOGIN_GROUPS set, OIDC logins are not restricted to teams")
  end
end
