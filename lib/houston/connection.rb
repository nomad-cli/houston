require 'uri'
require 'socket'
require 'openssl'
require 'forwardable'
require 'jwt'

module Houston
  class Connection
    extend Forwardable
    def_delegators :@ssl, :read, :write
    def_delegators :@uri, :scheme, :host, :port

    attr_reader :ssl, :socket, :certificate, :passphrase

    class << self
      def open_with_jwt(uri, private_key, team_id, key_id)
        return unless block_given?

        connection = new(uri, nil, nil)
        connection.initialize_with_p8(uri, private_key, team_id, key_id)
        connection.make_token

        yield connection
      end

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
      @jwt_token = JWT.encode({iss: @team_id}, ec_key, 'ES256', {kid: @key_id})
    end

    def write_via_jwt(payload, token)
      uri = URI.parse(@uri + '/3/device/'+token)
      http = Net::HTTP.new(uri.host, uri.port)

      #http.ca_file = "/tmp/ca-bundle.crt"
      #http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.use_ssl = true
     
      req = Net::HTTP::Post.new(uri, initheader = {'Content-Type': 'application/json', 
                                                   'apns-topic': "#{@bundle_id}",
                                                   Authorization: "bearer #{@jwt_token}"})
      req.body = payload.to_json
      res = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end
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
