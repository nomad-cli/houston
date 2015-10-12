require 'stringio'
require 'json'
require_relative '../lib/houston/notification'

module APNParser
  RULES = {
    1 => [:token, 'H*'],
    2 => [:payload, 'a*'],
    3 => [:id, 'N'],
    4 => [:expiry, 'N'],
    5 => [:priority, 'c']
  }

  def self.parse_notification res
    payload = JSON.parse(res.delete(:payload))
    aps = payload.delete('aps')
    Houston::Notification.new res.merge(payload).merge(
      alert: aps['alert'],
      badge: aps['badge'],
      sound: aps['sound'],
      category: aps['category'],
      content_available: aps['content-available'] == 1
    )
  end

  def self.read(io)
    c, size = io.read(5).unpack('cN')
    data = io.read(size)
    io = StringIO.new data, 'rb'
    res = {}
    while !io.eof?
      code, size = io.read(3).unpack('cn')
      key, rule = RULES[code]
      raise "Invalid code" if !key
      res[key] = io.read(size).unpack(rule)[0]
    end

    res
  end
end
