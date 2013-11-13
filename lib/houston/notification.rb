require 'json'

module Houston
  class Notification
    MAXIMUM_PAYLOAD_SIZE = 256

    attr_accessor :token, :alert, :badge, :sound, :content_available, :custom_data, :id, :expiry, :priority
    attr_reader :sent_at

    alias :device :token
    alias :device= :token=

    def initialize(options = {})
      @token = options.delete(:token) || options.delete(:device)
      @alert = options.delete(:alert)
      @badge = options.delete(:badge)
      @sound = options.delete(:sound)
      @expiry = options.delete(:expiry)
      @id = options.delete(:id)
      @priority = options.delete(:priority)
      @content_available = options.delete(:content_available)

      @custom_data = options
    end

    def payload
      json = {}.merge(@custom_data || {})
      json['aps'] ||= {}
      json['aps']['alert'] = @alert if @alert
      json['aps']['badge'] = @badge.to_i rescue 0 if @badge
      json['aps']['sound'] = @sound if @sound
      json['aps']['content-available'] = 1 if @content_available

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

    private
    
    def device_token_item
      [1, 32, @token.gsub(/[<\s>]/, '')].pack('cnH*')
    end

    def payload_item
      json = payload.to_json
      [2, json.bytes.count, json].pack('cna*')
    end

    def identifier_item
      [3, 4, @id].pack('cnN') unless @id.nil?
    end

    def expiration_item
      [4, 4, @expiry].pack('cnN') unless @expiry.nil?
    end

    def priority_item
      [5, 1, @priority].pack('cnc') unless @priority.nil?
    end
  end
end
