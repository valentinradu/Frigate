require "curl"
require "json"
require "test-unit"

class ServerTest < Test::Unit::TestCase
  @@credentials = JSON.parse(File.read("account.json"))

  def test_post_user_gift_request

    #a121-3212-dee3-dfe0
    #user_name: Mgoet stars: 5 word_count:5
    #user_name: Bookgirl05 stars: 1 word_count:71
    #user_name: f.s.s. stars: 5 word_count:12
    withUser("f.s.s.", "f.s.s@gmail.com", "US", "a121-3212-dee3-dfe0", "owned", false, nil)
    withUser("Mgoet", "Mgoet@gmail.com", "US", "a144-3212-dee3-dfe0", "available", true, "word_count_too_low")
    withUser("Bookgirl05", "Bookgirl05@gmail.com", "US", "a133-3212-dee3-dfe0", "available", true, "rating_too_low")
    withUser("RandomGuy", "RandomGuy@gmail.com", "US", "bbb3-3212-dee3-dfe0", "available", true, "review_not_found")
  end

  def withUser(name, email, store_front, uuid, expected_state, expected_rejected, expected_rejected_reason)
    curl = Curl.options("https://localhost:9292/gifts/#{uuid}") do |curl| curl.ssl_verify_peer = false end
    body = JSON.parse curl.body_str
    gift_id = body[0]["id"]
    assert_not_nil(gift_id)

    data = {:email => email,
            :user_name => name,
            :gift_id => gift_id,
            :store_front => store_front}
    curl = Curl.post("https://localhost:9292/giftRequest/#{uuid}", JSON.generate(data)) do |curl| curl.ssl_verify_peer = false end
    body = JSON.parse curl.body_str
    assert_equal(gift_id, body["id"], body)

    curl = Curl.post("https://localhost:9292/giftRequest/#{uuid}", JSON.generate(data)) do |curl| curl.ssl_verify_peer = false end
    assert_equal(400, curl.response_code, curl.status)

    curl = Curl.get("https://localhost:9292/gifts/#{uuid}") do |curl| curl.ssl_verify_peer = false end
    body = JSON.parse curl.body_str
    assert_equal("requested", body.find { |s| s["id"] == gift_id }["state"])

    data = {:passkey => @@credentials["passkey"]}
    curl = Curl.post("https://localhost:9292/processRequests", JSON.generate(data)) do |curl| curl.ssl_verify_peer = false end
    body = JSON.parse curl.body_str
    assert_equal(expected_state, body.find {|s| s["id"] == gift_id }["state"], body)
    assert_equal(expected_rejected, body.find {|s| s["id"] == gift_id }["rejected"], body)
    assert_equal(expected_rejected_reason, body.find {|s| s["id"] == gift_id }["rejection_reason"], body)
  end
end




#
