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

    def push(*notifications, &update_block)
      @mutex = Mutex.new
      @failed_notifications = []

      beginning = Time.now

      @connections = []
      10.times{
        connection = Connection.new(@gateway_uri, @certificate, @passphrase)
        connection.open
        @connections << connection
      }
      logger = Logger.new("michel_test.log", 'daily')
      logger.info("#{Process.pid} - Connections creation took: #{Time.now - beginning}")

      beginning = Time.now
      notifications.flatten!
      notifications.each_with_index{|notification, index| notification.id = index}

      notifications.each_slice(3000) do |subgroup|
        error_index = send_notifications(subgroup, &update_block)
        while error_index > -1
          subgroup.shift(error_index + 1)
          subgroup.each{|n|n.mark_as_unsent!}
          error_index = send_notifications(subgroup, &update_block)
        end
      end

      logger = Logger.new("michel_test.log", 'daily')
      logger.info("#{Process.pid} - finished after #{Time.now - beginning}")

      @failed_notifications
    end

    def get_connection
      @mutex.synchronize do
        Thread.new {
          connection = Connection.new(@gateway_uri, @certificate, @passphrase)
          connection.open
          @connections << connection
        }
        @connections.shift || Connection.new(@gateway_uri, @certificate, @passphrase)
      end
    end

    def send_notifications(notifications, &update_block)
      return -2 if notifications.empty?
      error_index = -1

      connection = get_connection
      logger = Logger.new("michel_test.log", 'daily')
      logger.info("get connection")
      logger.info("#{Process.pid} - starting at index: #{notifications[0].id}")

      ssl = connection.ssl

      Thread.abort_on_exception=true
      read_thread = nil

      write_thread = Thread.new do
        begin
          request = notifications.map(&:message).join
          puts request
          connection.write(request)
        rescue => error
          logger = Logger.new("michel_test.log", 'daily')
          logger.error("#{Process.pid} - #{error}")
        end
        # sleep in order to receive last errors from apple in read thread
        # if regular_exit
        logger = Logger.new("michel_test.log", 'daily')
        logger.info("#{Process.pid} - sleep")
        sleep(2)
        read_thread.exit
        puts 'read thread was closed by write thread'
        # end
      end

      read_thread = Thread.new do
        begin
          read_socket, write_socket, errors = IO.select([ssl], [], [ssl], nil)
          if (read_socket && read_socket[0])
            if error = connection.read(6)
              command, status, index = error.unpack("ccN")
              error_index = notifications.index{|n|n.id == index}
              logger.error("IM HERE") if error_index == nil
              logger = Logger.new("michel_test.log", 'daily')
              logger.error("#{Process.pid} - error_at:#{Time.now.to_s}, error_code: #{status}, index_error: #{error_index}, token: #{notifications[error_index].token}, certificate: #{@certificate.split(//).last(65).join}")
              write_thread.exit
              notifications[error_index].apns_error_code = status
              @failed_notifications << notifications[error_index]
              connection.close
              if block_given?
                update_block.call(error_index) if error_index
              end
              read_thread.exit
            end
          end
        rescue
          puts "redo line 134"
          redo
        end
      end

      read_thread.join

      # end
      error_index
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
