class App < Sinatra::Base

  @udid_match = /[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}/

  class << self
    def database_at_path(path)
      ActiveRecord::Base.logger = Logger.new(STDOUT)
      ActiveRecord::Base.establish_connection(
       :adapter   => 'sqlite3',
       :database  => path
      )

      ActiveRecord::Schema.define do
        unless table_exists? :gifts
          create_table :gifts do |table|
              table.column :device_id, :integer
              table.column :name, :string
              table.column :state, :string #owned, requested, available
          end
        end
        unless table_exists? :devices
          create_table :devices do |table|
              table.column :udid, :string
              table.column :email, :string
              table.column :user_name, :string
          end
        end
      end
    end
  end

  configure :development do
    enable :logging
    database_at_path './development.db'
    Rufus::Scheduler.new.every '2s' do
      
    end
  end

  before %r{\/.*\/(#{@udid_match})} do |udid|
    @device = Device.find_or_create_by(udid: udid)
    halt 500 if @device.nil?
    unless Array(@device.gifts).count > 0
      @device.gifts.create(:name => "Gift 1", :state => "available")
      @device.gifts.create(:name => "Gift 2", :state => "available")
    end
  end

  get %r{\/gifts\/(#{@udid_match})} do |state|
    @device.gifts.select{|gift| gift.state != "available"}.to_json
  end

  options %r{\/gifts\/(#{@udid_match})} do
    @device.gifts.select{|gift| gift.state == "available"}.to_json
  end

  post "*" do
    @json_data = JSON.parse request.body.read
    request.body.rewind
    pass
  end

  post %r{\/giftRequest\/(#{@udid_match})} do
    @email = @json_data["email"]
    @user_name = @json_data["user_name"]
    @gift_id = @json_data["gift_id"] if @json_data["gift_id"].to_s =~ %r{^\d+$}

    halt 400, JSON.generate({:message => "User name is mandatory"}) if @user_name.nil?
    halt 400, JSON.generate({:message => "User name is not valid"}) unless @user_name.length > 0
    halt 400, JSON.generate({:message => "Email is not valid"}) unless @email =~ %r{[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+}
    halt 400, JSON.generate({:message => "Gift id is not valid"}) if @gift_id.nil?

    @device.email = @email
    @device.user_name = @user_name

    gift = @device.gifts.find_by_id(@gift_id)
    halt 404, JSON.generate({:message => "Gift not found"}) if gift.nil?
    halt 500, JSON.generate({:message => "Unable to update gift"}) unless gift.update_attributes(:state => "requested")

    content_type :json
    gift.to_json
  end
end










#
