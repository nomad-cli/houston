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
    ENV['APN_CERTIFICATE'] = nil
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

  specify '#session uses a persistent connection for multiple calls to #push, #devices' do
    socket = MiniTest::Mock.new
    ssl = MiniTest::Mock.new
    ssl.expect(:sync=, true, [true])
    ssl.expect(:connect, true)
    ssl.expect(:close, nil)
    ssl.expect(:read, nil, [38])
    4.times { socket.expect(:nil?, false) }
    socket.expect(:close, nil)

    TCPSocket.stub(:new, socket) do
      client = Houston::Client.development certificate: fixture('cert.pem'), passphrase: 'example'
      OpenSSL::SSL::SSLSocket.stub(:new, ssl) do
        client.session do |session|
          session.push(Object.new)
          session.push(Object.new)
          session.devices
        end
      end
    end
    socket.verify
    ssl.verify
  end

  specify '#devices opens a session if none is active' do
    socket = MiniTest::Mock.new
    ssl = MiniTest::Mock.new
    ssl.expect(:sync=, true, [true])
    ssl.expect(:connect, true)
    ssl.expect(:read, nil, [38])
    TCPSocket.stub(:new, socket) do
      client = Houston::Client.development certificate: fixture('cert.pem'), passphrase: 'example'
      OpenSSL::SSL::SSLSocket.stub(:new, ssl) do
        client.devices
      end
    end
    socket.verify
    ssl.verify
  end

end


# Seems to be more of a connection test.
# tcp_mock = MiniTest::Mock.new
# tcp_mock.expect(:call, tcp_mock, ["gateway.sandbox.push.apple.com", 2195])
# #tcp_mock.expect(:close, nil)
# TCPSocket.stub(:new, tcp_mock) do
#   client = Houston::Client.development
#   client.session do |session|

#   end
# end
# assert tcp_mock.verify