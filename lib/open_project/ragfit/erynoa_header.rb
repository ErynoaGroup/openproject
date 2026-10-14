# frozen_string_literal: true

# RagFit patch 0005 (erynoa-header, 2026-10-14): Erynoa header above the OpenProject layout.
# GPLv3 §10 modification, see CHANGES-RAGFIT.md.
#
# The vendored package public/erynoa/1.1.1/ (ErynoaGroup/.assets, tag erynoa-header-v1.1.1, MIT code; Erynoa
# name and logo not licensed, see its NOTICE.md) is served unchanged as static files. This file only renders the
# partial with the package's markup and resolves its placeholders at request time:
# - domain: RAGFIT_ERYNOA_DOMAIN, otherwise the configured host name minus its first label
#   (plan.<domain> -> <domain>). No host name is written into the repository.
# - logo link: RAGFIT_ERYNOA_HOME_URL (https only), otherwise https://source.<domain>/
# - skip link: #content-wrapper; current service: plan (aria-current="page")
# - theme: data-erh-theme="dark|light" from the user's theme, none when it follows the OS
# Without a resolvable domain nothing is rendered. Works without JavaScript (the package JS is not used).
module OpenProject
  module Ragfit
    module ErynoaHeader
      VERSION = "1.1.1"
      ASSET_PATH = "/erynoa/#{VERSION}".freeze
      SERVICES = %w[source plan memory docs auth].freeze
      CURRENT = "plan"
      SKIP_TARGET = "#content-wrapper"
      HOST_LABEL = /\A(?!-)[a-z0-9-]{1,63}(?<!-)\z/

      module_function

      def valid_domain?(domain)
        labels = domain.to_s.split(".")
        labels.size >= 2 && labels.all? { |label| label.match?(HOST_LABEL) }
      end

      def domain(env: ENV, host_name: Setting.host_name)
        configured = env["RAGFIT_ERYNOA_DOMAIN"].to_s.strip.downcase
        return (valid_domain?(configured) ? configured : nil) unless configured.empty?

        host = host_name.to_s.strip.downcase.sub(%r{\A[a-z]+://}, "").split(%r{[:/]}, 2).first.to_s
        _first, rest = host.split(".", 2)
        valid_domain?(rest) ? rest : nil
      end

      def home_url(domain, env: ENV)
        configured = env["RAGFIT_ERYNOA_HOME_URL"].to_s.strip
        return configured if configured.match?(%r{\Ahttps://[^\s"'<>]+\z})

        "https://source.#{domain}/"
      end

      def service_url(service, domain)
        "https://#{service}.#{domain}/"
      end

      # "dark", "light", or nil (follow the OS preference).
      def theme(user = User.current)
        pref = user&.pref
        return nil if pref.nil? || pref.sync_with_os_theme?

        pref.dark_color_mode? ? "dark" : "light"
      end

      def show?(params)
        params.nil? || params[:layout].nil?
      end

      class Hook < OpenProject::Hook::ViewListener
        render_on :view_layouts_base_html_head, partial: "ragfit/erynoa_header_head"
        render_on :view_layouts_base_body_top, partial: "ragfit/erynoa_header"
      end
    end
  end
end
