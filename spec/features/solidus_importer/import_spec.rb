# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Import from CSV files' do # rubocop:disable RSpec/DescribeClass
  subject(:import) { SolidusImporter::ProcessImport.import_from_file(import_file, import_type) }

  let(:import_file) {}
  let(:import_type) {}

  before { allow(Spree::LogEntry).to receive(:create!) }

  context 'with a customers source file' do
    let(:import_file) { solidus_importer_fixture_path('customers.csv') }
    let(:import_type) { :customers }
    let(:csv_file_rows) { 4 }
    let(:user_emails) { ['jane.doe@acme.com', 'john.doe@acme.com'] }
    let(:imported_customer) { Spree::User.last }
    let!(:state) { create(:state, abbr: 'ON', country_iso: 'CA') }

    it 'imports some customers' do
      expect { import }.to change(Spree::User, :count).by(2)
      expect(import.state).to eq('completed')
      expect(Spree::User.where(email: user_emails).count).to eq(2)
      expect(Spree::LogEntry).to have_received(:create!).exactly(csv_file_rows).times
    end

    it 'import customer with addresses' do
      import
      expect(imported_customer.addresses.reload).not_to be_empty
    end
  end

  context 'with a products file' do
    let(:import_file) { solidus_importer_fixture_path('products.csv') }
    let(:import_type) { :products }
    let(:csv_file_rows) { 7 }
    let(:product_slug) { 'hightop-sports-sneaker' }
    let(:image_url) { 'https://cdn.shopify.com/shopify-marketing_assets/static/tobias-lutke-shopify.jpg' }
    let!(:shipping_category) { create(:shipping_category) }

    before do
      allow(URI).to receive(:open).and_call_original
      allow(URI).to receive(:open).with(image_url) do
        File.open(solidus_importer_fixture_path('thinking-cat.jpg'))
      end
    end

    it 'imports some products' do # rubocop:disable RSpec/MultipleExpectations
      expect { import }.to change(Spree::Product, :count).by(1)
      product = Spree::Product.last
      expect(product.variants.count).to eq(3)
      expect(product.slug).to eq(product_slug)
      expect(import.state).to eq('completed')
      expect(product.images).not_to be_empty
      expect(product.option_types.count).to eq 2
      expect(product.variants.sample.option_values.count).to eq 2
      expect(product.variants.sample.images).not_to be_empty
      expect(Spree::Product.last.images).not_to be_empty
      expect(Spree::Variant.last.images).not_to be_empty
      expect(Spree::LogEntry).to have_received(:create!).exactly(csv_file_rows).times
    end
  end

  context 'with an invalid products file' do
    let(:import_file) { solidus_importer_fixture_path('invalid_product.csv') }
    let(:import_type) { :products }
    let!(:shipping_category) { create(:shipping_category) }

    it 'fails to import the product' do
      expect { import }.not_to change(Spree::Product, :count)
      expect(import.rows.first.messages).to eq("Validation failed: Name can't be blank")
    end
  end

  context 'with Shopify Product CSVs' do
    before do
      allow(URI).to receive(:open)
    end

    context 'with the export from Shopify Product CSVs - Apparel' do
      let(:import_file) { solidus_importer_fixture_path('apparel.csv') }
      let(:import_type) { :products }
      let!(:shipping_category) { create(:shipping_category) }

      it 'imports a some products and a blue shirt with no variants' do
        expect { import }.to change(Spree::Product, :count).from(0)
        expect(import.state).to eq('completed')

        product = Spree::Product.find_by(slug: 'ocean-blue-shirt')

        expect(product.variants.count).to be_zero
      end
    end

    context 'with the export from Shopify Product CSVs - Jewelry' do
      let(:import_file) { solidus_importer_fixture_path('jewelery.csv') }
      let(:import_type) { :products }
      let!(:shipping_category) { create(:shipping_category) }

      it 'imports a some products and a clay pot with two variants' do
        expect { import }.to change(Spree::Product, :count).from(0)
        expect(import.state).to eq('completed')

        product = Spree::Product.find_by(slug: 'gemstone')

        expect(product.variants.count).to eq 2
        expect(product.variants.find_by(sku: 'gemstone-blue')).to be_present
        expect(product.variants.find_by(sku: 'gemstone-purple')).to be_present
      end
    end

    context 'with the export from Shopify Product CSVs - Home and Garden' do
      let(:import_file) { solidus_importer_fixture_path('home-and-garden.csv') }
      let(:import_type) { :products }
      let!(:shipping_category) { create(:shipping_category) }

      it 'imports a some products' do
        expect { import }.to change(Spree::Product, :count).from(0)
        expect(import.state).to eq('completed')

        product = Spree::Product.find_by(slug: 'clay-plant-pot')

        expect(product.variants.count).to eq 2
        expect(product.variants.find_by(sku: 'clay-plant-pot-large')).to be_present
        expect(product.variants.find_by(sku: 'clay-plant-pot-regular')).to be_present
      end
    end
  end

  context 'with a orders file' do
    let(:import_file) { solidus_importer_fixture_path('orders.csv') }
    let(:import_type) { :orders }
    let(:csv_file_rows) { 3 }
    let(:order_numbers) { ['#MA-3097', '#MA-3098'] }
    let!(:store) { create(:store) }
    let!(:state) { create(:state, abbr: 'ON', country_iso: 'CA') }
    let(:credit_owed_order) { Spree::Order.first }
    let(:balance_due_order) { Spree::Order.second }
    let(:payment) { imported_order.payments.first }
    let!(:variant) { create(:variant, sku: 'a-123') }

    before do
      create(:variant, sku: 'a-456')
      create(:variant, sku: 'b-001')
    end

    it 'imports some orders' do
      expect { import }.to change(Spree::Order, :count).from(0).to(2)
      expect(Spree::Order.where(number: order_numbers).count).to eq(2)
      expect(import.state).to eq('completed')
      expect(Spree::LogEntry).to have_received(:create!).exactly(csv_file_rows).times
    end

    it 'import an order with a line items' do
      import
      expect(credit_owed_order.line_items).not_to be_blank
    end

    xit 'import an order with bill and ship addresses' do
      import
      expect(credit_owed_order.bill_address).not_to be_blank
      expect(credit_owed_order.ship_address).not_to be_blank
      expect(credit_owed_order.bill_address.state).to eq state
      expect(credit_owed_order.bill_address.country).to eq state.country
    end

    it 'import the "credit owed" order with payments' do
      import
      expect(credit_owed_order.payments).not_to be_empty
      expect(credit_owed_order.payment_state).to eq 'credit_owed'
      expect(credit_owed_order.payments.first.state).to eq 'completed'
      expect(credit_owed_order.payment_total).to eq credit_owed_order.payments.first.amount
    end

    it 'import the "balance due" order with no transactions' do
      import
      expect(balance_due_order.payments).to be_empty
    end
  end
end
