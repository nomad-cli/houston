require 'spec_helper'

describe Houston::Notification do
  let(:notification_options) {
    {
      token: '<ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969>',
      alert: 'Houston, we have a problem.',
      badge: 2701,
      sound: 'sosumi.aiff',
      expiry: 1234567890,
      id: 42,
      priority: 10,
      content_available: true,
      # custom data
      key1: 1,
      key2: 'abc'
    }
  }

  subject { Houston::Notification.new(notification_options) }

  its(:token) { should == '<ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969>' }
  its(:alert) { should == 'Houston, we have a problem.' }
  its(:badge) { should == 2701 }
  its(:sound) { should == 'sosumi.aiff' }
  its(:expiry) { should == 1234567890 }
  its(:id) { should == 42 }
  its(:priority) { should == 10 }
  its(:content_available) { should be_true }
  its(:custom_data) { should == { key1: 1, key2: 'abc' } }

  context 'using :device instead of :token' do
    subject do
      notification_options[:device] = notification_options[:token]
      notification_options.delete(:token)
      Houston::Notification.new(notification_options)
    end

    its(:device) { '<ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969>' }
  end

  describe '#payload' do
    it 'should create a compliant dictionary' do
      subject.payload.should == {
        'aps' => {
          'alert' => 'Houston, we have a problem.',
          'badge' => 2701,
          'sound' => 'sosumi.aiff',
          'content-available' => 1
        },
        :key1 => 1,
        :key2 => 'abc'
      }
    end

    it 'should create a dictionary of only custom data and empty aps' do
      Houston::Notification.new(key1: 123, key2: 'xyz').payload.should == {
        'aps' => {},
        :key1 => 123,
        :key2 => 'xyz'
      }
    end

    it 'should create a dictionary only with alerts' do
      Houston::Notification.new(alert: 'Hello, World!').payload.should == {
        'aps' => { 'alert' => 'Hello, World!' }
      }
    end

    it 'should create a dictionary only with badges' do
      Houston::Notification.new(badge: '123').payload.should == {
        'aps' => { 'badge' => 123 }
      }
    end

    it 'should create a dictionary only with sound' do
      Houston::Notification.new(sound: 'ring.aiff').payload.should == {
        'aps' => { 'sound' => 'ring.aiff' }
      }
    end

    it 'should create a dictionary only with content-available' do
      Houston::Notification.new(content_available: true).payload.should == {
        'aps' => { 'content-available' => 1 }
      }
    end

    it 'should allow custom data inside aps key' do
      notification_options = { :badge => 567, 'aps' => { 'loc-key' => 'my-key' } }
      Houston::Notification.new(notification_options).payload.should == {
        'aps' => { 'loc-key' => 'my-key', 'badge' => 567 }
      }
    end
  end

  describe '#sent?' do
    it 'should be false initially' do
      subject.sent?.should be_false
    end

    it 'should be true after marking as sent' do
      subject.mark_as_sent!
      subject.sent?.should be_true
    end

    it 'should be false after marking as unsent' do
      subject.mark_as_sent!
      subject.mark_as_unsent!
      subject.sent?.should be_false
    end
  end

  describe '#message' do
    it 'should create a message with command 2' do
      command, _1, _2 = subject.message.unpack('cNa*')
      command.should == 2
    end

    it 'should create a message with correct frame length' do
      _1, length, _2 = subject.message.unpack('cNa*')
      length.should == 182
    end

    def parse_items(items_stream)
      items = []
      until items_stream.empty?
        item_id, item_length, items_stream = items_stream.unpack('cna*')
        item_data, items_stream = items_stream.unpack("a#{item_length}a*")
        items << [item_id, item_length, item_data]
      end
      items
    end

    it 'should include five items' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      parse_items(items_stream).should have(5).items
    end

    it 'should include an item #1 with the token as hexadecimal' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      items.should include([1, 32, ['ce8be6272e43e85516033e24b4c289220eeda4879c477160b2545e95b68b5969'].pack('H*')])
    end

    it 'should include an item #2 with the payload as JSON' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      items.should include([2, 126, '{"key1":1,"key2":"abc","aps":{"alert":"Houston, we have a problem.","badge":2701,"sound":"sosumi.aiff","content-available":1}}'])
    end

    it 'should include an item #3 with the identifier' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      items.should include([3, 4, [42].pack('N')])
    end

    it 'should include an item #4 with the expiry' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      items.should include([4, 4, [1234567890].pack('N')])
    end

    it 'should include an item #4 with the priority' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      items.should include([5, 1, [10].pack('c')])
    end

    it 'might be missing the identifier item' do
      notification_options.delete(:id)
      notification = Houston::Notification.new(notification_options)
      msg = notification.message
      _1, _2, items_stream = notification.message.unpack('cNa*')
      items = parse_items(items_stream)
      items.should have(4).items
      items.find { |item| item[0] == 3 }.should be_nil
    end

    it 'might be missing the expiry item' do
      notification_options.delete(:expiry)
      notification = Houston::Notification.new(notification_options)
      msg = notification.message
      _1, _2, items_stream = notification.message.unpack('cNa*')
      items = parse_items(items_stream)
      items.should have(4).items
      items.find { |item| item[0] == 4 }.should be_nil
    end

    it 'might be missing the priority item' do
      notification_options.delete(:priority)
      notification = Houston::Notification.new(notification_options)
      msg = notification.message
      _1, _2, items_stream = notification.message.unpack('cNa*')
      items = parse_items(items_stream)
      items.should have(4).items
      items.find { |item| item[0] == 5 }.should be_nil
    end
  end
end
