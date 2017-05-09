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

    def self.write_via_jwt(uri_str, private_key, team_id, key_id, payload, token)
      ec_key = OpenSSL::PKey::EC.new(private_key)
      jwt_token = JWT.encode({iss: team_id, iat: Time.now.to_i}, ec_key, 'ES256', {kid: key_id})

      client = NetHttp2::Client.new(uri_str)
      h = {}
      h['content-type'] = 'application/json'
      h['apns-expiration'] = '0'
      h['apns-priority'] = '10'
      h['apns-topic'] = ENV['APN_TOPIC'].to_s
      h['authorization'] = "bearer #{jwt_token}"
      res = client.call(:post, '/3/device/'+token, body: payload.to_json, timeout: 50, 
                        headers: h) 
      client.close
      return nil if res.status.to_i == 200
      res.body
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
