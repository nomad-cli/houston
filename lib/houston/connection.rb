require 'uri'
require 'socket'
require 'openssl'
require 'forwardable'
require 'jwt'
require 'net-http2'

module Houston
  class Connection
    extend Forwardable
    def_delegators :@ssl, :read, :write
    def_delegators :@uri, :scheme, :host, :port

    attr_reader :ssl, :socket, :certificate, :passphrase

    class << self
      def open(uri, certificate, passphrase)
        return unless block_given?

        connection = new(uri, certificate, passphrase)
        connection.open

        yield connection

        connection.close
      end
    end

    def initialize_with_p8(uri, private_key, team_id, key_id)
      @uri = uri
      @private_key = private_key.to_s
      @team_id = team_id.to_s
      @key_id = key_id.to_s
      @bundle_id = ''
    end

    def initialize(uri, certificate, passphrase)
      @uri = URI(uri)
      @certificate = certificate.to_s
      @passphrase = passphrase.to_s
    end

    def open
      return false if open?

      @socket = TCPSocket.new(@uri.host, @uri.port)

      context = OpenSSL::SSL::SSLContext.new
      context.key = OpenSSL::PKey::RSA.new(@certificate, @passphrase)
      context.cert = OpenSSL::X509::Certificate.new(@certificate)

      @ssl = OpenSSL::SSL::SSLSocket.new(@socket, context)
      @ssl.sync = true
      @ssl.connect
    end

    def make_token
      ec_key = OpenSSL::PKey::EC.new(@private_key)
      JWT.encode({iss: @team_id}, ec_key, 'ES256', {kid: @key_id})
    end

    def self.write_via_jwt(uri_str, private_key, team_id, key_id, payload, token)
      puts '|'+uri_str+'|'
      connection = new(uri_str, nil, nil)
      connection.initialize_with_p8(uri_str, private_key, team_id, key_id)
      jwt_token = connection.make_token
      puts jwt_token

      #http.ca_file = "/tmp/ca-bundle.crt"
      #http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      client = NetHttp2::Client.new(uri_str)
      h = {}
      h['content-type'] = 'application/json'
      h['apns-topic'] = ENV['APN_TOPIC']
      h['authorization'] = "bearer #{jwt_token}"
      res = client.call(:post, '/3/device/'+token, body: payload.to_json, timeout: 50, 
                        headers: h) 
      client.close
      puts 11114444433331.to_s
      puts res.status
      puts res.body
      return nil if res.status.to_i == 200
      res.body
    rescue Object => o
      puts o.inspect
    end

    def open?
      not (@ssl && @socket).nil?
    end

    def close
      return false if closed?

      @ssl.close
      @ssl = nil

      @socket.close
      @socket = nil
    end

    def closed?
      not open?
    end
  end
end
