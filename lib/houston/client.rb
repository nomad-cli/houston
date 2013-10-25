module Houston
  APPLE_PRODUCTION_GATEWAY_URI = "apn://gateway.push.apple.com:2195"
  APPLE_PRODUCTION_FEEDBACK_URI = "apn://feedback.push.apple.com:2196"

  APPLE_DEVELOPMENT_GATEWAY_URI = "apn://gateway.sandbox.push.apple.com:2195"
  APPLE_DEVELOPMENT_FEEDBACK_URI = "apn://feedback.sandbox.push.apple.com:2196"

  class Client
    attr_accessor :gateway_uri, :feedback_uri, :certificate, :passphrase, :timeout

    class << self
      def development(opts = {})
        new opts.merge  gateway_uri:  APPLE_DEVELOPMENT_GATEWAY_URI,
                        feedback_uri: APPLE_DEVELOPMENT_FEEDBACK_URI
      end

      def production(opts = {})
        new opts.merge  gateway_uri:  APPLE_PRODUCTION_GATEWAY_URI,
                        feedback_uri: APPLE_PRODUCTION_FEEDBACK_URI
      end
    end

    def initialize(opts = {})
      @gateway_uri  = opts.fetch :gateway_uri,  ENV['APN_GATEWAY_URI']
      @feedback_uri = opts.fetch :feedback_uri, ENV['APN_FEEDBACK_URI']
      @certificate  = opts.fetch :certificate,  ENV['APN_CERTIFICATE']
      @passphrase   = opts.fetch :passphrase,   ENV['APN_CERTIFICATE_PASSPHRASE']
      @timeout      = opts.fetch :timeout,      ENV['APN_TIMEOUT'] || 0.5
    end

    def session
      open_connection
      yield self
      close_connection
    end

    def open_connection
      return if @connection && @connection.open?
      @connection = Connection.new( @gateway_uri,
                                    @certificate,
                                    @passphrase )
      @connection.open
    end

    def close_connection
      @connection = @connection.close if @connection
    end

    def push(*notifications)
      return if notifications.empty?
      open_connection

      notifications.flatten!
      error = nil

      ssl = @connection.ssl

      notifications.each_with_index do |notification, index|
        next unless notification.kind_of?(Notification)
        next if notification.sent?

        notification.id = index

        @connection.write(notification.message)
        notification.mark_as_sent!

        break if notifications.count == 1 || notification == notifications.last

        read_socket, write_socket = IO.select([ssl], [ssl], [ssl], nil)
        if (read_socket && read_socket[0])
          error = @connection.read(6)
          break
        end
      end

      return if notifications.count == 1

      unless error
        read_socket, write_socket = IO.select([ssl], nil, [ssl], timeout)
        if (read_socket && read_socket[0])
          error = @connection.read(6)
        end
      end

      if error
        command, status, index = error.unpack("cci")
        notifications.slice!(0..index)
        notifications.each(&:mark_as_unsent!)
        close_connection
        push(*notifications)
      end
    rescue OpenSSL::SSL::SSLError, Errno::EPIPE
      close_connection
      retry
    end

    def devices
      open_connection
      devices = []

      while line = @connection.read(38)
        feedback = line.unpack('N1n1H140')
        token = feedback[2].scan(/.{0,8}/).join(' ').strip
        devices << token if token
      end

      devices
    end
  end
end
