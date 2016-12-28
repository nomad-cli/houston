require 'json'

module Houston
  class Notification
    class APNSError < RuntimeError
      # See: https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/CommunicatingWIthAPS.html#//apple_ref/doc/uid/TP40008194-CH101-SW12
      CODES = {
        0 => 'No errors encountered',
        1 => 'Processing error',
        2 => 'Missing device token',
        3 => 'Missing topic',
        4 => 'Missing payload',
        5 => 'Invalid token size',
        6 => 'Invalid topic size',
        7 => 'Invalid payload size',
        8 => 'Invalid token',
        10 => 'Shutdown',
        255 => 'Unknown error'
      }

      attr_reader :code

      def initialize(code)
        raise ArgumentError unless CODES.include?(code)
        super(CODES[code])
        @code = code
      end
    end

    MAXIMUM_PAYLOAD_SIZE = 2048

    attr_accessor :token, :alert, :badge, :sound, :category, :content_available, :mutable_content,
                  :custom_data, :id, :expiry, :priority
    attr_reader :sent_at
    attr_writer :apns_error_code

    alias :device :token
    alias :device= :token=

    def initialize(options = {})
      @token = options.delete(:token) || options.delete(:device)
      @alert = options.delete(:alert)
      @badge = options.delete(:badge)
      @sound = options.delete(:sound)
      @category = options.delete(:category)
      @expiry = options.delete(:expiry)
      @id = options.delete(:id)
      @priority = options.delete(:priority)
      @content_available = options.delete(:content_available)
      @mutable_content = options.delete(:mutable_content)

      @custom_data = options
    end

    def payload
      json = {}.merge(@custom_data || {}).inject({}) { |h, (k, v)| h[k.to_s] = v; h }

      json['aps'] ||= {}
      json['aps']['alert'] = @alert if @alert
      json['aps']['badge'] = @badge.to_i rescue 0 if @badge
      json['aps']['sound'] = @sound if @sound
      json['aps']['category'] = @category if @category
      json['aps']['content-available'] = 1 if @content_available
      json['aps']['mutable-content'] = 1 if @mutable_content

      json
    end

    def message
      data = [device_token_item,
              payload_item,
              identifier_item,
              expiration_item,
              priority_item].compact.join
      [2, data.bytes.count, data].pack('cNa*')
    end

    def mark_as_sent!
      @sent_at = Time.now
    end

    def mark_as_unsent!
      @sent_at = nil
    end

    def sent?
      !!@sent_at
    end

    def valid?
      payload.to_json.bytesize <= MAXIMUM_PAYLOAD_SIZE
    end

    def error
      APNSError.new(@apns_error_code) if @apns_error_code && @apns_error_code.nonzero?
    end

    private

      def device_token_item
        [1, 32, @token.gsub(/[<\s>]/, '')].pack('cnH64')
      end

      def payload_item
        json = payload.to_json
        [2, json.bytes.count, json].pack('cna*')
      end

      def identifier_item
        [3, 4, @id].pack('cnN') unless @id.nil?
      end

      def expiration_item
        [4, 4, @expiry.to_i].pack('cnN') unless @expiry.nil?
      end

      def priority_item
        [5, 1, @priority].pack('cnc') unless @priority.nil?
      end
  end
end
