require "spaceship"
require "json"

countries = JSON.parse(File.read("countryCodesMapping.json"))
credentials = File.open("test.account").readlines.map(&:strip)

Spaceship::Tunes.login(credentials[0], credentials[1])
app = Spaceship::Tunes::Application.find(482745751)
data = []
countries.each do |code, name|
  begin
    reviews = app.reviews("ios", code)
    data << {:value => reviews.count, :name => name }
  rescue Spaceship::Client::UnexpectedResponse => detail
    puts "Failed to get reviews for #{code}"
  end
end

data = data.sort_by{|country|
  country[:value]
}
puts JSON.pretty_generate(data)




























#
