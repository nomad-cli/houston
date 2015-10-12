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

      def mock
        client = self.new
        client.gateway_uri = "apn://127.0.0.1:2195"
        client.feedback_uri = nil
        client
      end
    end

    #registers exception handler. upon uncaught exceptions the block will be called with exception object as argument
    def capture_exceptions &block
      @exception_handler = block
    end

    def logger
      if !Thread.current[:logger]
        logger = Logger.new("log/houston_test_#{Time.now.strftime('%Y%m%d')}.log")
        logger.datetime_format = Time.now.strftime "%Y-%m-%dT%H:%M:%S"
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{@pid}: #{datetime} #{severity}: #{msg}\n"
        end
        Thread.current[:logger] = logger
      else
        Thread.current[:logger]
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
      @connections_queue = Queue.new
      @connection_threads = []
      @measures = {}
    end

    def measure type
      t = Time.now
      yield
    ensure
      @measures[type] = (@measures[type] || 0) + (Time.now - t) #measure even if crushed
    end

    def push(notifications, packet_size: 10)
      @failed_notifications = []

      beginning = Time.now

      5.times{ add_connection }
      logger.info("Connections creation took: #{Time.now - beginning}")

      beginning = Time.now
      notifications.each_with_index{|notification, index| notification.id = index}

      sent_count = 0
      while !notifications.empty?
        local_start_index = sent_count
        logger.info("Get connection, starting at index: #{notifications[0].id}")
        connection = measure(:get_connection){ get_connection }

        last_sent_id = nil
        write_thread = Thread.new(connection, notifications) do |connection, notifications|
          begin
            notifications.each_slice(packet_size) do |group|
              last_sent_id = group[-1].id
              write_notifications(connection, group)

              sent_count += group.size
              yield sent_count
            end
          rescue => e #purpose of this catch is to allow read thread to throw ErrorResponse
            log_exception!(e, "write")
          end

          logger.info("end of write")
          connection.socket.close_write #should send EOF to server making it send EOF back
        end

        error_index = read_errors(connection, notifications)
        puts "--- Got error at #{error_index}"
        write_thread.kill
        connection.close

        break if !error_index

        if error_index < 0 #custom errors, restart from next batch
          error_index = last_sent_id ? notifications.index{|n| n.id == last_sent_id } : 0
        end

        sent_count = local_start_index + error_index + 1
        yield sent_count
        notifications.shift(error_index + 1)
      end

      logger.info("Finished after #{Time.now - beginning}")
      logger.info("Measures: #{@measures.to_json}")

      @failed_notifications
    ensure
      threads, @connection_threads = @connection_threads, []
      threads.each{|t| t.join(5) } #allow started connections to finish opening, shouldn't kill in the middle
      @connections_queue.pop.close while !@connections_queue.empty? #clean whole pool
    end

    def add_connection
      connection = Connection.new(@gateway_uri, @certificate, @passphrase)
      connection.open
      @connections_queue << connection
    end

    def get_connection
      @connection_threads << Thread.new{ add_connection }
      @connections_queue.pop #blocking if empty
    end

    def log_exception!(e, where)
      @exception_handler.call(e) if @exception_handler
      logger.error "* #{e.class.name} on #{where}: #{e.message}\n" + e.backtrace[0,5].join("\n")
      nil
    end

    def write_notifications(connection, notifications)
      messages = notifications.map do |noti|
        begin
          measure(:message){noti.message}
        rescue => e
          log_exception!(e, "create notification message")
        end
      end

      request = messages.compact.join
      measure(:write){connection.write(request)}
    end

    def read_errors(connection, notifications)
      error = connection.read(6) #returns nil on EOF at start
      return nil if !error #ok

      command, error_code, error_noti_id = error.unpack("ccN")
      error_index = notifications.index{|n| n.id == error_noti_id }
      error_noti = notifications[error_index] if error_index
      if error_noti
        logger.error("Error_code: #{error_code}, id: #{error_noti.id}, index: #{error_index}, token: #{error_noti.token}, certificate: #{@certificate_for_log}")
        error_noti.apns_error_code = error_code
        @failed_notifications << error_noti
        error_index
      else
        logger.error("Invalid notification ID in error")
        -3 #since we don't know in which notification was error, we'll skip whole batch as if it was ok
      end
    rescue => e #TODO: create statistics of errors, maybe should be different handling of different types
      log_exception!(e, "read")
      -4
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
