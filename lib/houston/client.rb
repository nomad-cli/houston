module Houston
  APPLE_PRODUCTION_GATEWAY_URI = "apn://gateway.push.apple.com:2195"
  APPLE_PRODUCTION_FEEDBACK_URI = "apn://feedback.push.apple.com:2196"

  APPLE_DEVELOPMENT_GATEWAY_URI = "apn://gateway.sandbox.push.apple.com:2195"
  APPLE_DEVELOPMENT_FEEDBACK_URI = "apn://feedback.push.apple.com:2196"

  class Client
    attr_accessor :gateway_uri, :feedback_uri, :certificate, :passphrase, :gateway_connection, :feedback_connection

    def initialize
      @gateway_uri = ENV['APN_GATEWAY_URI']
      @feedback_uri = ENV['APN_FEEDBACK_URI']
      @certificate = ENV['APN_CERTIFICATE']
      @passphrase = ENV['APN_CERTIFICATE_PASSPHRASE']
    end

    def self.development
      client = self.new
      client.gateway_uri = APPLE_DEVELOPMENT_GATEWAY_URI
      client.feedback_uri = APPLE_DEVELOPMENT_FEEDBACK_URI
      client
    end

    def self.production
      client = self.new
      client.gateway_uri = APPLE_PRODUCTION_GATEWAY_URI
      client.feedback_uri = APPLE_PRODUCTION_FEEDBACK_URI
      client
    end

    def push(*notifications)
      return if notifications.empty?

      use_connection(:gateway) do |connection|
        notifications.flatten.each do |notification|
          next unless notification.kind_of?(Notification)
          next if notification.sent?

          connection.write(notification.message)
          notification.mark_as_sent!
        end
      end
    end

    def devices
      devices = []

      use_connection(:feedback) do |connection|
        while line = connection.read(38)
          feedback = line.unpack('N1n1H140')
          token = feedback[2].scan(/.{0,8}/).join(' ').strip
          devices << token if token
        end
      end

      devices
    end

    def connection_options_for_endpoint(endpoint = :gateway)
      uri = case endpoint
              when :gateway then URI(@gateway_uri)
              when :feedback then URI(@feedback_uri)
              else
                raise ArgumentError
            end

      {
        certificate: @certificate,
        passphrase: @passphrase,
        host: uri.host,
        port: uri.port
      }
    end

    private

      def use_connection(kind)
        return unless block_given? and kind

        connection = (send(:"#{kind}_connection") || Connection.new(connection_options_for_endpoint(kind)))
        should_close = !connection.open?
        connection.open unless connection.open?

        yield connection

        connection.close if should_close
      end
  end
end
