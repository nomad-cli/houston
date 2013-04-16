require 'uri'
require 'socket'
require 'openssl'
require 'forwardable'

module Houston
  class Connection
    attr_reader :ssl, :socket, :host, :port, :certificate, :passphrase

    extend Forwardable
    def_delegators :@ssl, :read, :write

    class << self
      def open(options = {})
        return unless block_given?

        connection = new(options)
        connection.open

        yield connection

        connection.close
      end
    end

    def initialize(options = {})
      [:host, :port, :certificate].each do |option|
        raise ArgumentError, "Missing connection parameter: #{option}" unless options.has_key?(option)
      end

      @host = options[:host]
      @port = options[:port]
      @certificate = options[:certificate]
      @passphrase = options[:passphrase]
    end

    def open
      return false if open?

      @socket = TCPSocket.new(@host, @port)

      context = OpenSSL::SSL::SSLContext.new
      context.key = OpenSSL::PKey::RSA.new(@certificate, @passphrase)
      context.cert = OpenSSL::X509::Certificate.new(@certificate)

      @ssl = OpenSSL::SSL::SSLSocket.new(@socket, context)
      ssl.sync = true
    end

    def open?
      not (@ssl and @socket).nil?
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
