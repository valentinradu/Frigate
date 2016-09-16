ActiveRecord::Schema.define do
  unless table_exists? :gifts
    create_table :gifts do |table|
        table.column :device_id, :integer
        table.column :app_id, :integer
        table.column :name, :string
        table.column :state, :string #owned, requested, available
        table.column :kind, :string #appstore, facebook, twitter
        table.column :store_front, :string
        table.column :user_name, :string
        table.column :content, :string
        table.column :forceful, :boolean
        table.column :forceful_content, :string
        table.column :rejected, :boolean
        table.column :rejection_reason, :string
        table.column :iap_product_id, :string
        table.column :receipt, :string
    end
  end
  unless table_exists? :devices
    create_table :devices do |table|
        table.column :udid, :string
        table.column :email, :string
        table.column :apn_token, :string
    end
  end
end
