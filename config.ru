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
require_relative "model"
require_relative "server"

webrick_options = {
  :Port               => 9292,#8443,
  :Logger             => WEBrick::Log::new($stdout, WEBrick::Log::DEBUG),
  :SSLEnable          => true,
  :SSLCertificate     => OpenSSL::X509::Certificate.new( File.open("./cert.crt").read ),
  :SSLPrivateKey      => OpenSSL::PKey::RSA.new(         File.open("./pkey.pem").read ),
  :SSLCertName        => [ [ "CN", WEBrick::Utils::getservername ] ]
}

#run App
Rack::Handler::WEBrick.run App, webrick_options
