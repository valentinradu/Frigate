require "curl"
require "json"
require "test-unit"

class ServerTest < Test::Unit::TestCase
  def test_post_user_gift_request
    curl = Curl.options("http://localhost:9292/gifts/a121-3212-dee3-dfe0")
    assert_not_nil(curl.body_str)
    body = JSON.parse curl.body_str
    gift_id = body[0]["id"]
    assert_not_nil(gift_id)

    data = {:email => "radu.v@gmail.com",
            :user_name => "monkey_pants",
            :gift_id => gift_id}
    curl = Curl.post("http://localhost:9292/giftRequest/a121-3212-dee3-dfe0", JSON.generate(data))
    assert_not_nil(curl.body_str)

    body = JSON.parse curl.body_str
    assert_not_nil(body)
    assert_equal(gift_id, body["id"])

    curl = Curl.get("http://localhost:9292/gifts/a121-3212-dee3-dfe0")
    assert_not_nil(curl.body_str)
    body = JSON.parse curl.body_str
    puts body
    assert_equal("requested", body.find {|s| s["id"] == gift_id }["state"])
  end
end




#
