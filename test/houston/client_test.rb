require_relative '../test_helper'

describe Houston::Client do
  before do
    @default_opts = { gateway_uri: 'http://example.com:666',
                      feedback_uri: 'http://example.com:777',
                      passphrase: 'Houston, I have a bad feeling about this mission.',
                      timeout: 1 }
  end

  specify '.new accepts a hash of options' do
    ENV['APN_CERTIFICATE'] = '-----BEGIN CERTIFICATE-----'
    client = Houston::Client.new @default_opts
    client.gateway_uri.must_equal @default_opts[:gateway_uri]
    client.feedback_uri.must_equal @default_opts[:feedback_uri]
    client.passphrase.must_equal @default_opts[:passphrase]
    client.timeout.must_equal @default_opts[:timeout]
    client.certificate.must_equal '-----BEGIN CERTIFICATE-----'
  end

  specify '.development sets the gateway and feedback uri for you' do
    client = Houston::Client.development @default_opts
    client.gateway_uri.must_equal   Houston::APPLE_DEVELOPMENT_GATEWAY_URI
    client.feedback_uri.must_equal  Houston::APPLE_DEVELOPMENT_FEEDBACK_URI
    client.timeout.must_equal @default_opts[:timeout]
  end

  specify '.production sets the gateway and feedback uri for you' do
    client = Houston::Client.production @default_opts
    client.gateway_uri.must_equal   Houston::APPLE_PRODUCTION_GATEWAY_URI
    client.feedback_uri.must_equal  Houston::APPLE_PRODUCTION_FEEDBACK_URI
    client.timeout.must_equal @default_opts[:timeout]
  end
end