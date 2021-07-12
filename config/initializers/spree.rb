# frozen_string_literal: true

Spree::Backend::Config.configure do |config|
  config.menu_items << config.class::MenuItem.new(
    :imports,
    'download',
    condition: -> { can?(:admin, Spree::Product) },
    label: :importer,
    url: :admin_solidus_importer_imports_path
  )
end

MIME::Types.add(MIME::Type.new(["application/csv", "csv"]), true)
MIME::Types.add(MIME::Type.new(["application/vnd.ms-excel", "csv"]), true)
