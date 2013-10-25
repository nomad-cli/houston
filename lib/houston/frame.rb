require 'json'

module Houston
  class Frame
    extend Forwardable
    COMMAND = 2

    def initialize(token, payload, id, expiry, priority)
      @items = []
      @items.push FrameItem.device_token(token)
      @items.push FrameItem.payload(payload)
      @items.push FrameItem.identifier(id)
      @items.push FrameItem.expiry(expiry)
      @items.push FrameItem.priority(priority)
    end

    def frame
      @items.join
    end

    def frame_length
      frame.bytesize
    end

    def to_s
      [COMMAND, frame_length].pack('CN') + frame
    end
  end

  class FrameItem
    DEVICE_TOKEN_NO = 1
    PAYLOAD_NO      = 2
    IDENTIFIER_NO   = 3
    EXPIRATION_NO   = 4
    PRIORITY_NO     = 5

    def self.device_token(token)
      hex = [token.gsub(/[<\s>]/, '')].pack('H*')
      new DEVICE_TOKEN_NO, hex.bytesize, hex
    end

    def self.payload(payload)
      json = payload.to_json
      new PAYLOAD_NO, json.bytesize, json
    end

    def self.identifier(id)
      new IDENTIFIER_NO, 4, id
    end

    def self.expiry(time)
      new EXPIRATION_NO, 4, @expiry.to_i
    end

    def self.priority(value)
      new PRIORITY_NO, 1, value, 'C'
    end

    def initialize(number, data_length, data, directive = nil)
      @number = number
      @data_length = data_length
      @data = data
      @directive = directive
      @directive ||= case data
      when String
        'A*'
      when Fixnum
        'N'
      end
    end

    def to_s
      [@number, @data_length, @data].pack("Cn#{@directive}")
    end
  end
end