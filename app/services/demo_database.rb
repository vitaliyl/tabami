# frozen_string_literal: true

require "sequel"
require "fileutils"
require "json"
require "time"

module Tabami
  module Services
    class DemoDatabase
      DEFAULT_PATH = File.expand_path("../../db/demo.sqlite3", __dir__)

      def self.ensure_seeded!(path = DEFAULT_PATH)
        FileUtils.mkdir_p(File.dirname(path))
        return path if File.exist?(path) && File.size(path) > 1024

        db = Sequel.sqlite(path)
        create_schema(db)
        seed_data(db)
        db.disconnect
        path
      end

      def self.create_schema(db)
        db.create_table!(:categories) do
          primary_key :id
          String :name, null: false
          String :slug, null: false, unique: true
          String :description
        end

        db.create_table!(:customers) do
          primary_key :id
          String :name, null: false
          String :email, null: false, unique: true
          String :status, default: "active" # active, pending, suspended
          String :country, null: false
          Decimal :spent_total, size: [10, 2], default: 0.0
          DateTime :created_at, null: false
          String :notes
        end

        db.create_table!(:products) do
          primary_key :id
          foreign_key :category_id, :categories, null: false
          String :name, null: false
          String :sku, null: false, unique: true
          Decimal :price, size: [10, 2], null: false
          Integer :stock, default: 0
          TrueClass :is_active, default: true
          String :metadata # JSON string
        end

        db.create_table!(:orders) do
          primary_key :id
          foreign_key :customer_id, :customers, null: false
          String :order_number, null: false, unique: true
          String :status, default: "processing" # pending, processing, shipped, delivered, cancelled
          Decimal :total_amount, size: [10, 2], null: false
          String :shipping_address
          DateTime :placed_at, null: false
        end

        db.create_table!(:order_items) do
          primary_key :id
          foreign_key :order_id, :orders, null: false, on_delete: :cascade
          foreign_key :product_id, :products, null: false
          Integer :quantity, null: false, default: 1
          Decimal :unit_price, size: [10, 2], null: false
          Decimal :subtotal, size: [10, 2], null: false
        end

        db.create_table!(:audit_logs) do
          primary_key :id
          String :action, null: false
          String :entity_type, null: false
          Integer :entity_id
          String :payload # JSON string
          DateTime :created_at, null: false
        end
      end

      def self.seed_data(db)
        categories = [
          { name: "Electronics", slug: "electronics", description: "Gadgets, devices, and accessories" },
          { name: "Home & Kitchen", slug: "home-kitchen", description: "Appliances, cookware, and furniture" },
          { name: "Clothing", slug: "clothing", description: "Apparel, shoes, and jewelry" },
          { name: "Books", slug: "books", description: "Print and digital books" },
          { name: "Sports & Outdoors", slug: "sports-outdoors", description: "Gear and fitness equipment" }
        ]
        cat_ids = categories.map { |c| db[:categories].insert(c) }

        countries = %w[US CA GB DE FR JP AU NL SE CH]
        statuses = %w[active active active pending suspended]
        now = Time.now

        # Seed 150 customers
        customer_ids = (1..150).map do |i|
          db[:customers].insert(
            name: "Customer #{i} #{%w[Smith Johnson Williams Brown Jones Miller Davis Garcia Rodriguez Wilson].sample}",
            email: "user#{i}_#{rand(1000..9999)}@example.com",
            status: statuses.sample,
            country: countries.sample,
            spent_total: (rand * 1500).round(2),
            created_at: now - (rand(1..365) * 86_400),
            notes: i.even? ? "Priority VIP client #{i}" : nil
          )
        end

        # Seed 80 products
        product_ids = (1..80).map do |i|
          cat_id = cat_ids.sample
          price = (rand(10..400) + (rand(1..99) / 100.0)).round(2)
          db[:products].insert(
            category_id: cat_id,
            name: "Product #{%w[Ultra Pro Max Lite Quantum Prime Eco Smart].sample} #{i}",
            sku: "SKU-#{cat_id}-#{1000 + i}",
            price: price,
            stock: rand(0..250),
            is_active: rand > 0.1,
            metadata: JSON.generate({ weight_kg: (rand * 5).round(2), warranty_months: [12, 24, 36].sample, tags: %w[new featured bestseller].sample(2) })
          )
        end

        # Seed 250 orders and order items
        order_statuses = %w[pending processing shipped delivered delivered cancelled]
        (1..250).each do |i|
          cust_id = customer_ids.sample
          order_time = now - (rand(1..180) * 86_400)
          order_id = db[:orders].insert(
            customer_id: cust_id,
            order_number: "ORD-#{2026_000 + i}",
            status: order_statuses.sample,
            total_amount: 0.0,
            shipping_address: "#{rand(100..999)} Market Street, Suite #{rand(1..50)}",
            placed_at: order_time
          )

          total = 0.0
          rand(1..4).times do
            prod_id = product_ids.sample
            unit_price = (rand(20..200) + 0.99).round(2)
            qty = rand(1..5)
            sub = (unit_price * qty).round(2)
            total += sub

            db[:order_items].insert(
              order_id: order_id,
              product_id: prod_id,
              quantity: qty,
              unit_price: unit_price,
              subtotal: sub
            )
          end

          db[:orders].where(id: order_id).update(total_amount: total.round(2))
        end

        # Seed 100 audit logs
        actions = %w[user.login user.update order.create order.cancel product.stock_adjust]
        (1..100).each do |i|
          db[:audit_logs].insert(
            action: actions.sample,
            entity_type: %w[Customer Order Product Session].sample,
            entity_id: rand(1..100),
            payload: JSON.generate({ ip: "192.168.1.#{rand(1..254)}", user_agent: "Mozilla/5.0", timestamp: (now - rand(1..500_000)).iso8601 }),
            created_at: now - (rand(1..60) * 86_400)
          )
        end
      end
    end
  end
end
