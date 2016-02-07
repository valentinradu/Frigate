lib = File.expand_path('../spaceship/lib', File.dirname(__FILE__))
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "spaceship"
require "json"

countries = JSON.parse(File.read("countryCodesMapping.json"))

Spaceship::Tunes.login("ios.spaceship.builder@gmail.com", "121Ntr3#$%bar3")
app = Spaceship::Tunes::Application.find(482745751)
puts app.name
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
