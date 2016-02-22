require "curl"
require "json"
require "test-unit"

class ServerTest < Test::Unit::TestCase
  @@credentials = JSON.parse(File.read("account.json"))

  def test_user_gift_request_concurency
    data = {:email => "threepinkangels@gmail.com",
            :user_name => "threepinkangels",
            :store_front => "US"}
    helper_gift_request_with_process(data, "0021-1112-a333-0000", "owned", false, nil)
    data = {:email => "threepinkangels@gmail.com",
            :user_name => "threepinkangels",
            :store_front => "US"}
    result = helper_gift_request_without_process(data, "0021-1992-dee3-eee0", 400)
    assert_equal "review_already_claimed", result["message"], result
  end

  def test_user_gift_request_owned
    data = {:email => "f.s.s@gmail.com",
            :user_name => "F.S.s.",
            :store_front => "US"}
    helper_gift_request_with_process(data, "a235-3212-dee3-d0e0", "owned", false, nil)
  end

  def test_user_gift_request_word_count_too_low
    data = {:email => "Mgoet@gmail.com",
            :user_name => "MGOET",
            :store_front => "US"}
    helper_gift_request_with_process(data, "a144-3212-dee3-dfe0", "available", true, "word_count_too_low")
  end

  def test_user_gift_request_rating_too_low
    data = {:email => "Bookgirl05@gmail.com",
            :user_name => "Bookgirl05",
            :store_front => "US"}
    helper_gift_request_with_process(data, "a133-3212-dee3-dfe0", "available", true, "rating_too_low")
  end

  def test_user_gift_request_review_not_found
    data = {:email => "RandomGuy@gmail.com",
            :user_name => "RandomGuy",
            :store_front => "US"}
    helper_gift_request_with_process(data, "bbb3-3212-dee3-dfe0", "available", true, "review_not_found")
  end

  def test_user_gift_request_force
    data = {:email => "Das.Musiker@gmail.com",
            :user_name => "Das Musiker",
            :store_front => "US"}
    helper_gift_request_with_process(data, "a121-3212-dee3-dfe0", "owned", false, nil)
    data[:forceful] = true
    data[:forceful_content] = "forceful_content"
    helper_gift_request_without_process(data, "1111-3212-dee3-daa0", 201)
    helper_gift_request_with_process(data, "1111-3212-dee3-daa0", "available", true, "forceful_review_failed")
  end

  def helper_gift_request_without_process(data, uuid, expected_status)
    curl = Curl.options("https://localhost:9292/gifts/id/#{uuid}") do |curl| curl.ssl_verify_peer = false end
    body = JSON.parse curl.body_str
    gift_id = body[0]["id"]
    assert_equal(200, curl.response_code)
    assert_not_nil(gift_id)

    data[:gift_id] = gift_id
    data[:apn_token] = "apn_token"
    curl = Curl.post("https://localhost:9292/giftRequest/id/#{uuid}", JSON.generate(data)) do |curl| curl.ssl_verify_peer = false end
    body = JSON.parse curl.body_str
    assert_equal(expected_status, curl.response_code, body)
    body
  end

  def helper_gift_request_with_process(data, uuid, expected_state, expected_rejected, expected_rejected_reason)
    curl = Curl.options("https://localhost:9292/gifts/id/#{uuid}") do |curl| curl.ssl_verify_peer = false end
    body = JSON.parse curl.body_str
    assert_equal(200, curl.response_code)
    gift_id = body[0]["id"]
    assert_not_nil(gift_id)

    data[:gift_id] = gift_id
    data[:apn_token] = "apn_token"
    curl = Curl.post("https://localhost:9292/giftRequest/id/#{uuid}", JSON.generate(data)) do |curl| curl.ssl_verify_peer = false end
    body = JSON.parse curl.body_str
    assert_equal(201, curl.response_code, body)
    assert_equal(gift_id, body["id"], body)

    curl = Curl.post("https://localhost:9292/giftRequest/id/#{uuid}", JSON.generate(data)) do |curl| curl.ssl_verify_peer = false end
    assert_equal(400, curl.response_code, curl.status)

    curl = Curl.get("https://localhost:9292/gifts/id/#{uuid}") do |curl| curl.ssl_verify_peer = false end
    body = JSON.parse curl.body_str
    assert_equal(200, curl.response_code)
    assert_equal("requested", body.find { |s| s["id"] == gift_id }["state"])

    data = {:passkey => @@credentials["passkey"]}
    curl = Curl.post("https://localhost:9292/processAppstoreRequests", JSON.generate(data)) do |curl| curl.ssl_verify_peer = false end
    body = JSON.parse curl.body_str
    assert_equal(200, curl.response_code)
    assert_equal(expected_state, body.find {|s| s["id"] == gift_id }["state"], body)
    assert_equal(expected_rejected, body.find {|s| s["id"] == gift_id }["rejected"], body)
    assert_equal(expected_rejected_reason, body.find {|s| s["id"] == gift_id }["rejection_reason"], body)
  end
end




#
