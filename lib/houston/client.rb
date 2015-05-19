require 'logger'

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
      @certificate = File.read(ENV['APN_CERTIFICATE']) if ENV['APN_CERTIFICATE']
      @passphrase = ENV['APN_CERTIFICATE_PASSPHRASE']
      @timeout = Float(ENV['APN_TIMEOUT'] || 0.5)
    end

    def push(*notifications)
      return if notifications.empty?

      notifications.flatten!
      failed_notifications = []

      Connection.open(@gateway_uri, @certificate, @passphrase) do |connection|
        ssl = connection.ssl

        error_index = -1
        mutex = Mutex.new
        Thread.abort_on_exception=true

        read_thread = Thread.new do
         begin
           read_socket, write_socket, errors = IO.select([ssl], [], [ssl], nil)
           if (read_socket && read_socket[0])
             if error = connection.read(6)
               command, status, index = error.unpack("ccN")
               logger = Logger.new("houston_test.log", 'daily')
               logger.error("error_at:#{Time.now.to_s}, error_code: #{status}, index_error: #{index}")
               mutex.synchronize do
                 error_index = index
                 notifications[error_index].apns_error_code = status
                 failed_notifications << notifications[error_index]
               end
             end
           end
         rescue
           redo
         end
        end

        write_thread = Thread.new do
          notifications.each_with_index do |notification, index|
            begin
              last_time = Time.now
              next unless notification.kind_of?(Notification)
              next if notification.sent?
              next unless notification.valid?
              mutex.synchronize do
                if error_index > -1
                  connection.close
                  Thread.exit
                end
              end
              notification.id = index
              connection.write(notification.message)
              notification.mark_as_sent!
              logger = Logger.new("houston_test.log", 'daily')
              logger.info("sent_at:#{Time.now.to_s}, diff: #{Time.now - last_time}, token: #{notification.token}")
            rescue => error
              logger = Logger.new("houston_test.log", 'daily')
              logger.error("#{error.inspect}, token: #{notification.token}")
              mutex.synchronize do
                error_index = :general_error
              end
              redo
            end
          end
          # sleep in order to receive last errors from apple in read thread
          sleep(5)
        end

        write_thread.join
        read_thread.exit

        # start over with remaining notifications
        if error_index > -1 && error_index < notifications.size - 1
          notifications.shift(error_index + 1)
          notifications.each{|n|n.mark_as_unsent!}
          temp_connection = Houston::Connection.new(@gateway_uri, @certificate, @passphrase)
          temp_connection.open
          connection = temp_connection
          redo
        elsif error_index == :general_error
          temp_connection = Houston::Connection.new(@gateway_uri, @certificate, @passphrase)
          temp_connection.open
          connection = temp_connection
          redo
        end
      end
      failed_notifications
    end

    def unregistered_devices
      devices = []

      Connection.open(@feedback_uri, @certificate, @passphrase) do |connection|
        while line = connection.read(38)
          feedback = line.unpack('N1n1H140')
          timestamp = feedback[0]
          token = feedback[2].scan(/.{0,8}/).join(' ').strip
          devices << {token: token, timestamp: timestamp} if token && timestamp
        end
      end

      devices
    end

    def devices
      unregistered_devices.collect{|device| device[:token]}
    end
  end
end
