module RequestsProcessor
  def process_appstore_requests(user, password)
    gifts = Gift.where(:state => "requested", :kind => "appstore")
    return gifts if gifts.nil? or gifts.count <= 0

    gifts.group_by{|h| h.app_id}.each do |app_id, g_gifts|
      begin
        app = Spaceship::Tunes::Application.find(app_id)
      rescue RuntimeError
        Spaceship::Tunes.login(user,password)
        app = Spaceship::Tunes::Application.find(app_id)
      end

      g_gifts.group_by{|h| h.store_front}.each do |key, value|
        reviews = app.reviews("ios", key) rescue Spaceship::Client::UnexpectedResponse

        value.each do |gift|
          if review = reviews.select { |r|  r.nickname.downcase == gift.user_name.downcase }.first
            case
            when review.rating < 3
              gift.update_attributes(:state => "available", :rejected => true, :rejection_reason => "rating_too_low")
            when review.content.split.count < 10
              gift.update_attributes(:state => "available", :rejected => true, :rejection_reason => "word_count_too_low")
            else
              gift.update_attributes(:state => "owned", :rejected => false, :rejection_reason => nil)
            end
          else
            gift.update_attributes(:state => "available", :rejected => true, :rejection_reason => "review_not_found")
          end
        end
      end
    end

    gifts
  end
  def notify_devices(apn, gifts)
    gifts.group_by{|h| h.device}.each do |device, gifts|
      # "#{device.udid} : #{gifts.count} processed. #{gifts.select{|gift| gift.state == "owned"}.count} approved."

      # notification = Houston::Notification.new(device: device.apn_token)
      # notification.alert = "#{gifts.count} processed. #{gifts.select{|gift| gift.state == "owned"}.count} approved."
      # notification.badge = gifts.count
      # notification.category = "GIFTS_PROCESSED"
      # notification.content_available = true
      # notification.custom_data = gifts.to_json
      #
      # apn.push(notification)
    end
    gifts
  end
end

module DatabaseHelper
  def create_database_at_path(path)
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.establish_connection(
     :adapter   => 'sqlite3',
     :database  => path
    )

    ActiveRecord::Schema.define do
      unless table_exists? :gifts
        create_table :gifts do |table|
            table.column :device_id, :integer
            table.column :app_id, :integer
            table.column :name, :string
            table.column :state, :string #owned, requested, available
            table.column :kind, :string #appstore
            table.column :store_front, :string
            table.column :user_name, :string
            table.column :rejected, :boolean
            table.column :rejection_reason, :string
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
  end
end

class App < Sinatra::Base

  set :static, false

  @@udid_match = /[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}/
  @@countries = JSON.parse(File.read("countryCodesMapping.json"))
  @@credentials = JSON.parse(File.read("account.json"))

  helpers RequestsProcessor

  configure :development do
    enable :logging
    Class.new.extend(DatabaseHelper).create_database_at_path './development.db'
    APN = Houston::Client.development
    # APN.certificate = File.read("apple_push_notification.pem")
    # Rufus::Scheduler.new.every '2s' do
    #   helper = Class.new.extend(RequestsProcessor)
    #   helper.notify_devices(APN, helper.process_appstore_requests(@@credentials["user"], @@credentials["password"]))
    # end
  end

  before %r{\/.*\/(#{@@udid_match})} do |udid|
    @device = Device.find_or_create_by(udid: udid)
    halt 500, JSON.generate({:message => "device_id_nil"}) if @device.nil?
    unless Array(@device.gifts).count > 0
      @device.gifts.create(:name => "Gift 1", :kind => "appstore", :state => "available", :rejected => false, :app_id => 482745751)
      @device.gifts.create(:name => "Gift 2", :kind => "appstore", :state => "available", :rejected => false, :app_id => 482745751)
      @device.gifts.create(:name => "Gift 3", :kind => "appstore", :state => "available", :rejected => false, :app_id => 482745751)
      @device.gifts.create(:name => "Gift 4", :kind => "appstore", :state => "available", :rejected => false, :app_id => 482745751)
      @device.gifts.create(:name => "Gift 5", :kind => "appstore", :state => "available", :rejected => false, :app_id => 482745751)
      @device.gifts.create(:name => "Gift 6", :kind => "appstore", :state => "available", :rejected => false, :app_id => 482745751)
      @device.gifts.create(:name => "Gift 7", :kind => "appstore", :state => "available", :rejected => false, :app_id => 482745751)
    end
  end

  get "/static/*.*" do |path, ext|
    file_path = "./static/#{path}.#{ext}"
    cache_control :public, :max_age => 60
    etag Digest::MD5.file(file_path).hexdigest rescue Errno::ENOENT
    send_file file_path
  end

  get %r{\/gifts\/(#{@@udid_match})} do |state|
    @device.gifts.select{|gift| gift.state != "available"}.to_json
  end

  options %r{\/gifts\/(#{@@udid_match})} do
    @device.gifts.select{|gift| gift.state == "available"}.to_json
  end

  post "*" do
    @json_data = JSON.parse request.body.read
    request.body.rewind
    pass
  end

  post "/processAppstoreRequests" do
    passkey = @@credentials["passkey"]

    halt 400, JSON.generate({:message => "invalid_request"}) if @json_data["passkey"].nil?
    halt 400, JSON.generate({:message => "invalid_passkey"}) if @json_data["passkey"] != passkey
    content_type :json
    status 200
    notify_devices(APN, process_appstore_requests(@@credentials["user"], @@credentials["password"])).to_json
  end

  post %r{\/giftRequest\/(#{@@udid_match})} do
    email = @json_data["email"]
    apn_token = @json_data["apn_token"]
    user_name = @json_data["user_name"]
    gift_id = @json_data["gift_id"] if @json_data["gift_id"].to_s =~ %r{^\d+$}
    store_front = @json_data["store_front"] if @@countries.keys.include? @json_data["store_front"].to_s

    halt 400, JSON.generate({:message => "user_name_mandatory"}) if user_name.nil?
    halt 400, JSON.generate({:message => "user_name_invalid"}) unless user_name.length > 0
    halt 400, JSON.generate({:message => "email_invalid"}) unless email =~ %r{[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+}
    halt 400, JSON.generate({:message => "gift_id_invalid"}) if gift_id.nil?
    halt 400, JSON.generate({:message => "store_front_invalid"}) if store_front.nil?
    halt 400, JSON.generate({:message => "apn_token_invalid"}) if apn_token.nil?

    @device.update_attributes(:email => email, :apn_token => apn_token)

    gift = @device.gifts.find_by_id(gift_id)
    halt 404, JSON.generate({:message => "gift_not_foud"}) if gift.nil?
    halt 400, JSON.generate({:message => "gift_cant_be_requested"}) unless gift["state"] == "available"
    halt 500, JSON.generate({:message => "gift_cant_be_updated"}) unless gift.update_attributes(:state => "requested",
                                                                                                :store_front => store_front,
                                                                                                :user_name => user_name)
    content_type :json
    status 201
    gift.to_json
  end
end










#
