# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RagFit Erynoa header", type: :rails_request do
  def header_html
    Nokogiri::HTML(response.body).at_css("body > header.erh")
  end

  context "with a host name that has a base domain", with_settings: { host_name: "plan.example.org" } do
    it "renders the header as first element of the body, without JavaScript" do
      get "/login"
      header = header_html
      expect(header).to be_present
      first = Nokogiri::HTML(response.body).at_css("body").element_children.first
      expect(first.name).to eq("header")
      expect(first["class"]).to eq("erh")
      expect(header["role"]).to eq("banner")
      expect(header["data-erynoa-header"]).to eq("1.1.2")
      expect(header.at_css("a.erh-skip")["href"]).to eq("#content-wrapper")
      expect(header.at_css("a.erh-brand")["href"]).to eq("https://source.example.org/")
      expect(header.css("nav a").map { |a| a["href"] })
        .to eq(%w[source plan memory docs auth monitor].map { |s| "https://#{s}.example.org/" })
      expect(header.css("a[aria-current='page']").map { |a| a["data-erh-service"] }).to eq(["plan"])
      expect(header.css("script")).to be_empty
      expect(response.body).to include('href="/erynoa/1.1.2/erynoa-header.v1.css"')
      expect(response.body).to include('href="/erynoa/ragfit-plan-layout.css"')
      expect(response.body).not_to include("erynoa-header.v1.js")
    end

    it "sets data-erh-theme from the user's theme" do
      login_as create(:user, preferences: { theme: "dark" })
      get "/my/page"
      expect(header_html["data-erh-theme"]).to eq("dark")
    end

    it "omits data-erh-theme when the user follows the OS" do
      login_as create(:user, preferences: { theme: "sync_with_os" })
      get "/my/page"
      expect(header_html).to be_present
      expect(header_html["data-erh-theme"]).to be_nil
    end

    it "is not rendered when the page is requested without layout decoration" do
      get "/login", params: { layout: "false" }
      expect(header_html).to be_nil
    end
  end

  context "without a base domain", with_settings: { host_name: "localhost:3000" } do
    it "renders neither the header nor its stylesheets" do
      get "/login"
      expect(header_html).to be_nil
      expect(response.body).not_to include("/erynoa/")
    end
  end
end
