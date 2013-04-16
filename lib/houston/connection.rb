require 'uri'
require 'socket'
require 'openssl'

module Houston
  class Connection
    class << self
      def open(options = {})
        return unless block_given?

        [:certificate, :passphrase, :host, :port].each do |option|
          raise ArgumentError, "Missing connection parameter: #{option}" unless options[option]
        end

        socket = TCPSocket.new(options[:host], options[:port])

        context = OpenSSL::SSL::SSLContext.new
        context.key = OpenSSL::PKey::RSA.new(options[:certificate], options[:passphrase])
        context.cert = OpenSSL::X509::Certificate.new(options[:certificate])

        ssl = OpenSSL::SSL::SSLSocket.new(socket, context)
        ssl.sync = true
        ssl.connect
  
        yield ssl, socket
  
        ssl.close
        socket.close
      end
    end
  end
end
