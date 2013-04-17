module Houston
  APPLE_PRODUCTION_GATEWAY_URI = "apn://gateway.push.apple.com:2195"
  APPLE_PRODUCTION_FEEDBACK_URI = "apn://feedback.push.apple.com:2196"

  APPLE_DEVELOPMENT_GATEWAY_URI = "apn://gateway.sandbox.push.apple.com:2195"
  APPLE_DEVELOPMENT_FEEDBACK_URI = "apn://feedback.sandbox.push.apple.com:2196"

  class Client
    attr_accessor :gateway_uri, :feedback_uri, :certificate, :passphrase

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

      Connection.open(@gateway_uri, @certificate, @passphrase) do |connection|
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

      Connection.open(@feedback_uri, @certificate, @passphrase) do |connection|
        while line = connection.read(38)
          feedback = line.unpack('N1n1H140')
          token = feedback[2].scan(/.{0,8}/).join(' ').strip
          devices << token if token
        end
      end

      devices
    end
  end
end
