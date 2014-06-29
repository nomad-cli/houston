require 'json'

module Houston
  class Notification
    MAXIMUM_PAYLOAD_SIZE = 256
    DEFAULT_OMISSION = '...'

    attr_accessor :token, :alert, :badge, :sound, :content_available, :custom_data, :id, :expiry, :priority, :truncation, :omission
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
      @truncation = !!options.delete(:truncation)
      @omission = options.has_key?(:omission) ? options.delete(:omission) : DEFAULT_OMISSION

      @custom_data = options
    end

    def payload
      json = {}.merge(@custom_data || {})
      json['aps'] ||= {}
      json['aps']['alert'] = @alert if @alert
      json['aps']['badge'] = @badge.to_i rescue 0 if @badge
      json['aps']['sound'] = @sound ? @sound : nil
      json['aps']['content-available'] = 1 if @content_available

      truncate(json)

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
      payload_valid?(payload)
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
      [4, 4, @expiry.to_i].pack('cnN') unless @expiry.nil?
    end

    def priority_item
      [5, 1, @priority].pack('cnc') unless @priority.nil?
    end

    def truncate?(payload)
      @truncation && !payload_valid?(payload) && truncatable?(payload)
    end

    def truncate(payload)
      if truncate?(payload)
        alert = payload['aps']['alert'].byteslice(0, available_bytesize_for_alert(payload))
        alert = validate_alert_encoding(alert)
        payload['aps']['alert'] = @omission ? alert + @omission : alert
      end
    end

    def available_bytesize_for_alert(payload)
      tmp_payload = payload.dup
      tmp_payload['aps']['alert'] = @omission || ''
      tmp_bytesize = tmp_payload.to_json.bytesize

      MAXIMUM_PAYLOAD_SIZE > tmp_bytesize ? MAXIMUM_PAYLOAD_SIZE - tmp_bytesize : 0
    end

    def validate_alert_encoding(alert)
      if alert.force_encoding('UTF-8').valid_encoding?
        alert
      else
        validate_alert_encoding(alert.byteslice(0, alert.bytesize - 1))
      end
    end

    def payload_valid?(payload)
      payload.to_json.bytesize <= MAXIMUM_PAYLOAD_SIZE
    end

    def truncatable?(payload)
      if (alert = payload['aps']['alert'])
        !alert.empty?
      else
        false
      end
    end
  end
end
