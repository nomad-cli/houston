unless ENV['CI']
  require 'simplecov'

  SimpleCov.start do
    add_filter '/spec/'
  end
end

require 'houston'
require 'rspec'

class MockConnection
  class << self
    def open(uri, certificate, passphrase)
      yield self.new
    end
  end

  def initialize
    @unregistered_devices = [
      [443779200, 32, 'ce8be6272e43e85516033e24b4c289220eeda4879c477160b2545e95b68b5969'],
      [1388678223, 32, 'ce8be6272e43e85516033e24b4c289220eeda4879c477160b2545e95b68b5970']
    ]
  end

  def read(bytes)
    return nil if @unregistered_devices.empty?

    @unregistered_devices.shift.pack('N1n1H*')
  end
end
