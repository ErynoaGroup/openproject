# frozen_string_literal: true

# RagFit patch 0002 (oidc-admin-group, 2026-10-13): set the admin flag from a group claim on every OIDC login.
# GPLv3 §10 modification, see CHANGES-RAGFIT.md.
#
# Upstream maps "admin" only from a boolean claim (attribute_map admin). Some providers only send a
# "groups" array (e.g. "org" and "org:team" entries). With RAGFIT_OIDC_<PROVIDER>_ADMIN_GROUP set, the
# strategy returns admin: true when that group is in the userinfo "groups" claim and admin: false when the
# claim is present but does not contain it. Authentication::OmniauthService#update_admin_flag then grants
# or revokes admin on every login. Without the variable (or a blank one), or without a "groups" claim,
# nothing changes.
#
# Exactly one group per provider: the variable holds a single group name, not a list. Entries in the claim
# that are not strings are ignored. The comparison is case-insensitive and exact (no prefix match).
# RagFit | Source (Gitea) builds team entries as org.Name + ":" + lower-case team name, e.g.
# "ErynoaGroup:platform-admin"; set the variable to exactly that string.
module OpenProject::OpenIDConnect::RagfitAdminGroup
  module_function

  def env_name(provider_name)
    "RAGFIT_OIDC_#{provider_name.to_s.upcase.gsub(/[^A-Z0-9]/, '_')}_ADMIN_GROUP"
  end

  # Returns true, false or nil (nil: do not touch the admin flag).
  def admin_for(provider_name, raw_info, env: ENV)
    group = env[env_name(provider_name)].to_s.strip
    return nil if group.empty?

    groups = raw_info.respond_to?(:[]) ? (raw_info["groups"] || raw_info[:groups]) : nil
    return nil unless groups.is_a?(Array)

    groups.any? { |g| g.is_a?(String) && g.strip.casecmp?(group) }
  end

  module StrategyPatch
    def omniauth_hash_to_user_attributes(auth_hash)
      attributes = defined?(super) ? super : {}
      raw_info = auth_hash.dig("extra", "raw_info") || {}
      admin = OpenProject::OpenIDConnect::RagfitAdminGroup.admin_for(name, raw_info)
      admin.nil? ? attributes : attributes.merge(admin:)
    end
  end
end
