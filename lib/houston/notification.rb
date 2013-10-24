require 'json'

module Houston
  class Notification
    attr_accessor :token, :alert, :badge, :sound, :content_available, :custom_data, :id, :expiry
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
      json = payload.to_json
      device_token = [@token.gsub(/[<\s>]/, '')].pack('H*')
      @expiry ||= Time.now + 86400
      @id ||= 0
      id = @id.to_s
      priority = @content_available ? 5 : 10

      frame = ''
      frame << [1, device_token.bytesize, device_token].pack('CnA*')
      frame << [2, json.bytesize, json].pack('CnA*')
      frame << [3, id.bytesize, id].pack('CnA*')
      frame << [4, 4, @expiry].pack('CnN')
      frame << [5, 1, priority].pack('CnC')
      [2, frame.bytesize].pack('CN') + frame
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
  end
end


