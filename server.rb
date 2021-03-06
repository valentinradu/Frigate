require 'sinatra'
require 'active_record'
require 'json'
require 'curb'
require 'rufus-scheduler'
require 'spaceship'
require 'openssl'
require 'webrick'
require 'webrick/https'
require 'houston'
require 'mustache'
require 'venice'
require 'openssl'
require 'base64'
require 'sinatra/activerecord'

module RequestsProcessor
  @@private_key = OpenSSL::PKey::RSA.new(File.read "./pkey.pem")

  def process_twitter_requests()
    gifts = Gift.where(:state => "requested", :kind => "twitter")
    return gifts if gifts.nil? or gifts.count <= 0
    gifts.each do |gift|
      digest = OpenSSL::Digest::SHA256.new
      receipt = Base64.strict_encode64(@@private_key.sign digest, gift.iap_product_id)
      gift.update_attributes(:state => "owned", :rejected => false, :rejection_reason => nil, :receipt => receipt)
    end
    gifts
  end
  def process_facebook_requests()
    gifts = Gift.where(:state => "requested", :kind => "facebook")
    return gifts if gifts.nil? or gifts.count <= 0
    gifts.each do |gift|
      digest = OpenSSL::Digest::SHA256.new
      receipt = Base64.strict_encode64(@@private_key.sign digest, gift.iap_product_id)
      gift.update_attributes(:state => "owned", :rejected => false, :rejection_reason => nil, :receipt => receipt)
    end
    gifts
  end
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
              concurent_gifts = Gift.joins(:device).where("lower(user_name) == ? and devices.udid != ? and state == ?", gift.user_name.downcase, gift.device.udid, "owned")
              digest = OpenSSL::Digest::SHA256.new
              receipt = Base64.strict_encode64(@@private_key.sign digest, gift.iap_product_id)
              if concurent_gifts.nil? or concurent_gifts.count == 0
                gift.update_attributes(:state => "owned", :rejected => false, :rejection_reason => nil, :content => review.content, :receipt => receipt)
              else
                if gift.forceful_content.nil? or gift.forceful_content.length <= 0 or gift.forceful_content.downcase != review.content.downcase or concurent_gifts.map { |e| e.content.downcase }.include?(gift.forceful_content.downcase)
                  gift.update_attributes(:state => "available", :rejected => true, :rejection_reason => "forceful_review_failed")
                else
                  gift.update_attributes(:state => "owned", :rejected => false, :rejection_reason => nil, :content => review.content, :receipt => receipt)
                end
              end
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

class App < Sinatra::Base

  register Sinatra::ActiveRecordExtension

  set :static, false

  @@stores = JSON.parse(File.read "./static/stores.json")
  @@credentials = JSON.parse(File.read "./account.json")

  helpers RequestsProcessor

  configure :development do

    enable :logging

    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.establish_connection :development
    APN = Houston::Client.development
    # APN.certificate = File.read("apple_push_notification.pem")
    # Rufus::Scheduler.new.every '2s' do
    #   helper = Class.new.extend(RequestsProcessor)
    #   helper.notify_devices(APN, helper.process_appstore_requests(@@credentials["user"], @@credentials["password"]))
    # end
  end

  before %r{\/.*\/id/(.*)} do |udid|
    @device = Device.find_or_create_by(udid: udid)
    halt 500, JSON.generate({:message => "device_id_nil"}) if @device.nil?
    unless Array(@device.gifts).count > 0
      @device.gifts.create(:name => "Gift 1", :kind => "appstore", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 2", :kind => "facebook", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 3", :kind => "facebook", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 4", :kind => "twitter", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 5", :kind => "appstore", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 6", :kind => "facebook", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 7", :kind => "twitter", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 8", :kind => "appstore", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 9", :kind => "facebook", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 10", :kind => "facebook", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 11", :kind => "twitter", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 12", :kind => "appstore", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 13", :kind => "facebook", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 14", :kind => "twitter", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
      @device.gifts.create(:name => "Gift 15", :kind => "appstore", :state => "available", :rejected => false, :forceful => false, :app_id => 482745751, :iap_product_id => "com.valentinradu.cadenza.tier6")
    end
  end

  get "/static/*.*" do |path, ext|
    file_path = "./static/#{path}.#{ext}"
    cache_control :public, :max_age => 60
    etag Digest::MD5.file(file_path).hexdigest rescue Errno::ENOENT
    send_file file_path
  end

  get %r{\/gifts\/id/(.*)} do
    content_type :json
    status 200
    @device.gifts.select{|gift| gift.state != "available"}.to_json
  end

  options %r{\/gifts\/id/(.*)} do
    content_type :json
    status 200
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
    result = process_appstore_requests(@@credentials["user"], @@credentials["password"]).concat(process_twitter_requests()).concat(process_facebook_requests())
    notify_devices(APN, result).to_json
  end

  post %r{\/giftRequest\/id/(.*)} do |udid|
    email = @json_data["email"]
    apn_token = @json_data["apn_token"]
    user_name = @json_data["user_name"]
    gift_id = @json_data["gift_id"] if @json_data["gift_id"].to_s =~ %r{^\d+$}
    store_front = @json_data["store_front"] if @@stores.keys.include? @json_data["store_front"].to_s
    forceful = @json_data["forceful"]
    forceful_content = @json_data["forceful_content"]
    receipt = @json_data["receipt"]
    gift_iap_id = @json_data["gift_iap_id"]

    halt 404, JSON.generate({:message => "invalid_udid"}) if udid.nil? or udid.length <= 0

    attributes = {}
    if receipt.nil? or receipt.length <= 0 or gift_iap_id.nil? or gift_iap_id.length <= 0
      halt 400, JSON.generate({:message => "gift_id_invalid"}) if gift_id.nil?
      gift = @device.gifts.find_by_id(gift_id)
      halt 404, JSON.generate({:message => "gift_not_found"}) if gift.nil?
      halt 400, JSON.generate({:message => "gift_cant_be_requested"}) unless gift["state"] == "available"
      if gift.kind == "appstore"
        halt 400, JSON.generate({:message => "user_name_mandatory"}) if user_name.nil?
        halt 400, JSON.generate({:message => "user_name_invalid"}) unless user_name.length > 0
        halt 400, JSON.generate({:message => "email_invalid"}) unless email =~ %r{[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+}
        halt 400, JSON.generate({:message => "store_front_invalid"}) if store_front.nil?
        halt 400, JSON.generate({:message => "apn_token_invalid"}) if apn_token.nil?

        @device.update_attributes(:email => email, :apn_token => apn_token)

        concurent_gifts = Gift.joins(:device).where("lower(user_name) == ? and devices.udid != ? and state == ?", user_name.downcase, udid, "owned")
        unless concurent_gifts.nil? or concurent_gifts.count == 0
          halt 400, JSON.generate({:message => "review_already_claimed"}) if forceful.nil? or forceful == false
          halt 400, JSON.generate({:message => "forceful_review_content_missing"}) if forceful_content.nil? or forceful_content.length <= 0
          halt 400, JSON.generate({:message => "forceful_review_content_identical"}) if gift.content == forceful_content
          attributes[:forceful] = forceful
          attributes[:forceful_content] = forceful_content
        end
        attributes[:store_front] = store_front
        attributes[:user_name] = user_name
      end
      attributes[:state] = "requested"
    else
      gift = @device.gifts.find_by(:iap_product_id => gift_iap_id)
      halt 404, JSON.generate({:message => "gift_not_found"}) if gift.nil?
      halt 400, JSON.generate({:message => "receipt_not_valid"}) unless r = Venice::Receipt.verify(receipt)
      halt 400, JSON.generate({:message => "receipt_not_for_this_gift"}) unless r.product_id == gift[:iap_product_id]
      attributes[:state] = "owned"
      attributes[:receipt] = receipt
      attributes[:forceful] = false
      attributes[:forceful_content] = nil
      attributes[:rejected] = false
      attributes[:rejection_reason] = nil
    end

    halt 500, JSON.generate({:message => "gift_cant_be_updated"}) unless gift.update_attributes(attributes)
    content_type :json
    status 201
    gift.to_json
  end
end










#
