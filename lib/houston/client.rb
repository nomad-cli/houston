module Houston
  APPLE_PRODUCTION_GATEWAY_URI = "apn://gateway.push.apple.com:2195"
  APPLE_PRODUCTION_FEEDBACK_URI = "apn://feedback.push.apple.com:2196"

  APPLE_DEVELOPMENT_GATEWAY_URI = "apn://gateway.sandbox.push.apple.com:2195"
  APPLE_DEVELOPMENT_FEEDBACK_URI = "apn://feedback.sandbox.push.apple.com:2196"

  class Client
    attr_accessor :gateway_uri, :feedback_uri, :certificate, :passphrase, :timeout

    class << self
      def development
        client = self.new
        client.gateway_uri = APPLE_DEVELOPMENT_GATEWAY_URI
        client.feedback_uri = APPLE_DEVELOPMENT_FEEDBACK_URI
        client
      end

      def production
        client = self.new
        client.gateway_uri = APPLE_PRODUCTION_GATEWAY_URI
        client.feedback_uri = APPLE_PRODUCTION_FEEDBACK_URI
        client
      end
    end

    def initialize
      @gateway_uri = ENV['APN_GATEWAY_URI']
      @feedback_uri = ENV['APN_FEEDBACK_URI']
      @certificate = ENV['APN_CERTIFICATE']
      @passphrase = ENV['APN_CERTIFICATE_PASSPHRASE']
      @timeout = ENV['APN_TIMEOUT'] || 0.5
    end

    def push(*notifications)
      return if notifications.empty?

      notifications.flatten!
      error = nil

      Connection.open(@gateway_uri, @certificate, @passphrase) do |connection|
        ssl = connection.ssl

        notifications.each_with_index do |notification, index|
          next unless notification.kind_of?(Notification)
          next if notification.sent?
          next unless notification.valid?

          notification.id = index

          connection.write(notification.message)
          notification.mark_as_sent!

          break if notifications.count == 1 || notification == notifications.last

          read_socket, write_socket = IO.select([ssl], [ssl], [ssl], nil)
          if (read_socket && read_socket[0])
            error = connection.read(6)
            break
          end
        end

        return if notifications.count == 1

        unless error
          read_socket, write_socket = IO.select([ssl], nil, [ssl], timeout)
          if (read_socket && read_socket[0])
            error = connection.read(6)
          end
        end
      end

      if error
        command, status, index = error.unpack("ccN")
        notifications.slice!(0..index)
        notifications.each(&:mark_as_unsent!)
        push(*notifications)
      end
    end

    def unregistered_devices
      unregistered_devices_with_timestamps.map {|unregistered_device| unregistered_device[:token]}
    end

    alias :devices :unregistered_devices

    def unregistered_devices_with_timestamps
      unregistered_devices_with_timestamps = []

      Connection.open(@feedback_uri, @certificate, @passphrase) do |connection|
        while line = connection.read(38)
          feedback = line.unpack('N1n1H140')
          timestamp = feedback[0]
          token = feedback[2].scan(/.{0,8}/).join(' ').strip
          unregistered_devices_with_timestamps << {token: token, timestamp: timestamp} if token && timestamp
        end
      end

      unregistered_devices_with_timestamps
    end
  end
end
