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
      @id = options.delete(:id).to_i
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
      @expiry ||= Time.now + 86400
      priority = @content_available ? 5 : 10
      frame = Frame.new @token, payload, @id, @expiry, priority
      frame.to_s
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


