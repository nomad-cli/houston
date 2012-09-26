require 'json'

module Houston
  class Notification
    attr_accessor :device, :alert, :badge, :sound, :custom_data
    attr_reader :sent_at

    def initialize(options = {})
      @device = options.delete(:device)
      @alert = options.delete(:alert)
      @badge = options.delete(:badge)
      @sound = options.delete(:sound)

      @custom_data = options
    end

    def payload
      json = {}.merge(@custom_data || {})
      json['aps'] = {}
      json['aps']['alert'] = @alert
      json['aps']['badge'] = @badge.to_i rescue 0
      json['aps']['sound'] = @sound

      json
    end

    def message
      json = payload.to_json
      device_token = [@device.gsub(/[<\s>]/, '')].pack('H*')

      [0, 0, 32, device_token, 0, json.bytes.count, json].pack('ccca*cca*')
    end

    def mark_as_sent!
      @sent_at = Time.now
    end

    def sent?
      !!@sent_at
    end
  end
end
