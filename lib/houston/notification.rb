require 'json'

module Houston
  class Notification
    attr_accessor :token, :alert, :badge, :sound, :content_available, :custom_data
    attr_reader :sent_at

    alias :device :token
    alias :device= :token=

    def initialize(options = {})
      @token = options.delete(:token) || options.delete(:device)
      @alert = options.delete(:alert)
      @badge = options.delete(:badge)
      @sound = options.delete(:sound)
      @content_available = options.delete(:content_available)

      @custom_data = options
    end

    def payload
      json = {}.merge(@custom_data || {})
      json['aps'] = {}
      json['aps']['alert'] = @alert if @alert
      json['aps']['badge'] = @badge.to_i rescue 0 if @badge
      json['aps']['sound'] = @sound if @sound
      json['aps']['content-available'] = 1 if @content_available

      json
    end

    def message
      json = payload.to_json
      hex_token = [@token.gsub(/[<\s>]/, '')].pack('H*')

      [0, 0, 32, hex_token, 0, json.bytes.count, json].pack('ccca*cca*')
    end

    def mark_as_sent!
      @sent_at = Time.now
    end

    def sent?
      !!@sent_at
    end
  end
end
