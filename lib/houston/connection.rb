require 'uri'
require 'socket'
require 'openssl'
require 'forwardable'

module Houston
  class Connection
    attr_reader :ssl, :socket

    extend Forwardable
    def_delegators :@ssl, :read, :write

    def self.open(options = {})
      return unless block_given?

      connection = new(options)
      connection.open

      yield connection

      connection.close
    end

    def initialize(options = {})
      [:certificate, :host, :port].each do |option|
        raise ArgumentError, "Missing connection parameter: #{option}" unless options[option]
      end

      @options = options
    end

    def open
      return if open?

      @socket = TCPSocket.new(@options[:host], @options[:port])

      context = OpenSSL::SSL::SSLContext.new
      context.key = OpenSSL::PKey::RSA.new(@options[:certificate], @options[:passphrase])
      context.cert = OpenSSL::X509::Certificate.new(@options[:certificate])

      @ssl = OpenSSL::SSL::SSLSocket.new(@socket, context)
      @ssl.sync = true
      @ssl.connect
    end

    def open?
      (@socket and @ssl) != nil
    end

    def close
      @ssl.close
      @ssl = nil

      @socket.close
      @socket = nil
    end
  end
end
