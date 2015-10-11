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
      @certificate_for_log = @certificate.split(//).last(65).join if @certificate
      @passphrase = ENV['APN_CERTIFICATE_PASSPHRASE']
      @timeout = Float(ENV['APN_TIMEOUT'] || 0.5)
      @pid = Process.pid
      @logger = Logger.new("log/houston_test_#{Time.now.strftime('%Y%m%d')}.log")
      @logger.datetime_format = Time.now.strftime "%Y-%m-%dT%H:%M:%S"
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{@pid}: #{datetime} #{severity}: #{msg}\n"
      end
      @connections = []
    end

    def push(notifications)
      @mutex = Mutex.new
      @failed_notifications = []

      beginning = Time.now

      5.times{ add_connection }
      @logger.info("Connections creation took: #{Time.now - beginning}")

      beginning = Time.now
      notifications.each_with_index{|notification, index| notification.id = index}

      finished_count = 0
      notifications.each_slice(3000) do |batch|
        loop do
          error_index = send_batch(batch)
          break if error_index < 0

          batch.shift(error_index + 1)
        end

        finished_count += batch.size
        yield finished_count
      end

      @logger.info("Finished after #{Time.now - beginning}")

      @failed_notifications
    ensure
      @mutex.synchronize do
        @connections.each{|con| con.close } #close whole connection pool
      end
    end

    def add_connection
      @mutex.synchronize do
        connection = Connection.new(@gateway_uri, @certificate, @passphrase)
        connection.open
        @connections << connection
      end
    end

    def get_connection
      add_connection if @connections.empty? #connections were requested too frequently, add another one
      con = @connections.shift

      Thread.new{ add_connection }

      con
    end

    def log_exception!(e, where)
      if defined?(Rollbar) && (@last_error_type != e.class || @last_error_message != e.message)
        Rollbar.error(e)
        @last_error_type, @last_error_message = e.class, e.message
      end

      @logger.error "* #{e.class.name} on #{where}: #{e.message}\n" + e.backtrace[0,5].join("\n")
      nil
    end

    def write_notifications(notifications)
      alerted_error_types = {}
      messages = notifications.map do |noti|
        begin
          noti.message
        rescue => e
          log_exception!(e, "create notification message")
        end
      end

      request = messages.compact.join
      connection.write(request)
    rescue => e
      log_exception!(e, "write")
    end

    def read_errors(connection, notifications, already_tried = false)
      error = connection.read(6) #returns nil on EOF at start
      return -1 if !error #ok

      command, error_code, error_noti_id = error.unpack("ccN")
      error_index = notifications.index{|n| n.id == error_noti_id }
      error_noti = notifications[error_index] if error_index
      if error_noti
        @logger.error("Error_code: #{error_code}, id: #{error_noti.id}, index: #{error_index}, token: #{error_noti.token}, certificate: #{@certificate_for_log}")
        error_noti.apns_error_code = error_code
        @failed_notifications << error_noti
        error_index
      else
        @logger.error("Invalid notification ID in error")
        -3 #since we don't know in which notification was error, we'll skip whole batch as if it was ok
      end
    rescue => e #TODO: create statistics of errors, maybe should be different handling of different types
      log_exception!(e, "read")
      if already_tried
        @logger.error "Second read failure - closing!"
        -4
      else
        @logger.info "Retrying after 1 second..."
        sleep 1
        read_errors connection, notifications, true
      end
    end

    def send_batch(notifications)
      return -2 if notifications.empty?
      error_index = -1

      connection = get_connection
      @logger.info("get connection, starting at index: #{notifications[0].id}")

      Thread.abort_on_exception=true
      read_thread = nil

      write_thread = Thread.new do
        write_notifications notifications

        # sleep in order to receive last errors from apple in read thread
        @logger.info("end of write sleep 2 seconds")
        sleep(2)
        
        read_thread.exit
        @logger.info("write finished, read closed")
      end

      read_thread = Thread.new do
        error_index = read_errors connection, notifications
        write_thread.exit
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
