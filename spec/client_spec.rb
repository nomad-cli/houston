require 'spec_helper'

class MockConnection
  class << self
    def open(uri, certificate, passphrase)
      yield self.new
    end
  end

  def initialize
    @read_count = 0
    @unregistered_devices = [[443779200, 32, "ce8be6272e43e85516033e24b4c289220eeda4879c477160b2545e95b68b5969"], [1388678223, 32, "ce8be6272e43e85516033e24b4c289220eeda4879c477160b2545e95b68b5970"]]
  end

  def read(bytes)
    unregistered_device = @unregistered_devices[@read_count]
    @read_count += 1
    unregistered_device ? unregistered_device.pack('N1n1H*') : nil
  end
end

describe Houston::Client do
  subject { Houston::Client.development }

  before(:each) do
    stub_const("Houston::Connection", MockConnection)
  end

  describe '#unregistered_devices_with_timestamps' do
    it 'should correctly parse the feedback response and create a dictionary of unregistered devices with timestamps' do
      subject.unregistered_devices_with_timestamps.should == [
        {:token=>"ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969", :timestamp=>443779200},
        {:token=>"ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5970", :timestamp=>1388678223}
      ]
    end
  end

  describe '#unregistered_devices' do
    it 'should correctly parse the feedback response and create an array of unregistered devices' do
      subject.unregistered_devices.should == [
        "ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969",
        "ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5970"
      ]
    end
  end

  describe '#devices' do
    it 'should be an alias of unregistered_devices and return the exact same value' do
      subject.devices.should == subject.unregistered_devices
    end
  end
end


