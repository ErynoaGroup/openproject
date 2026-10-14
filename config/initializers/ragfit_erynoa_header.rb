# frozen_string_literal: true

# RagFit patch 0005 (erynoa-header): register the header hook listener (see lib/open_project/ragfit/erynoa_header.rb).
Rails.application.config.to_prepare do
  OpenProject::Ragfit::ErynoaHeader::Hook
end
