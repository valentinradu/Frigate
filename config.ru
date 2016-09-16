require_relative "model"
require_relative "server"

webrick_options = {
  :Port               => 9292,#8443,
  :Logger             => WEBrick::Log::new($stdout, WEBrick::Log::DEBUG),
  :SSLEnable          => true,
  :SSLCertificate     => OpenSSL::X509::Certificate.new(File.open("./cert.crt").read),
  :SSLPrivateKey      => OpenSSL::PKey::RSA.new(File.open("./pkey.pem").read),
  :SSLCertName        => [ [ "CN", WEBrick::Utils::getservername ] ]
}

#run App
Rack::Handler::WEBrick.run App, webrick_options
