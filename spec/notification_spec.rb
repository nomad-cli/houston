require 'spec_helper'

describe Houston::Notification do
  let(:notification_options) {
    {
      token: '<ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969>',
      alert: 'Houston, we have a problem.',
      badge: 2701,
      sound: 'sosumi.aiff',
      category: 'INVITE_CATEGORY',
      expiry: 1234567890,
      id: 42,
      priority: 10,
      content_available: true,
      key1: 1,
      key2: 'abc'
    }
  }

  subject { Houston::Notification.new(notification_options) }

  describe '#token' do
    subject { super().token }
    it { should == '<ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969>' }
  end

  describe '#alert' do
    subject { super().alert }
    it { should == 'Houston, we have a problem.' }
  end

  describe '#badge' do
    subject { super().badge }
    it { should == 2701 }
  end

  describe '#sound' do
    subject { super().sound }
    it { should == 'sosumi.aiff' }
  end

  describe '#category' do
    subject { super().category }
    it { should == 'INVITE_CATEGORY' }
  end

  describe '#expiry' do
    subject { super().expiry }
    it { should == 1234567890 }
  end

  describe '#id' do
    subject { super().id }
    it { should == 42 }
  end

  describe '#priority' do
    subject { super().priority }
    it { should == 10 }
  end

  describe '#content_available' do
    subject { super().content_available }
    it { should be_truthy }
  end

  describe '#custom_data' do
    subject { super().custom_data }
    it { should == { key1: 1, key2: 'abc' } }
  end

  context 'using :device instead of :token' do
    subject do
      notification_options[:device] = notification_options[:token]
      notification_options.delete(:token)
      Houston::Notification.new(notification_options)
    end

    describe '#device' do
      subject { super().device }
      it { should == '<ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969>' }
    end
  end

  describe '#payload' do
    it 'should create a compliant dictionary' do
      expect(subject.payload).to eq(        'aps' => {
          'alert' => 'Houston, we have a problem.',
          'badge' => 2701,
          'sound' => 'sosumi.aiff',
          'category' => 'INVITE_CATEGORY',
          'content-available' => 1
        },
        'key1' => 1,
        'key2' => 'abc')
    end

    it 'should create a dictionary of only custom data and empty aps' do
      expect(Houston::Notification.new(key1: 123, key2: 'xyz').payload).to eq(
        'aps' => {},
        'key1' => 123,
        'key2' => 'xyz'
      )
    end

    it 'should create a dictionary only with alerts' do
      expect(Houston::Notification.new(alert: 'Hello, World!').payload).to eq(
        'aps' => { 'alert' => 'Hello, World!' }
      )
    end

    it 'should create a dictionary only with badges' do
      expect(Houston::Notification.new(badge: '123').payload).to eq(
        'aps' => { 'badge' => 123 }
      )
    end

    it 'should create a dictionary only with sound' do
      expect(Houston::Notification.new(sound: 'ring.aiff').payload).to eq(
        'aps' => { 'sound' => 'ring.aiff' }
      )
    end

    it 'should create a dictionary only with category' do
      expect(Houston::Notification.new(category: 'INVITE_CATEGORY').payload).to eq(
        'aps' => { 'category' => 'INVITE_CATEGORY' }
      )
    end

    it 'should create a dictionary only with content-available' do
      expect(Houston::Notification.new(content_available: true).payload).to eq(
        'aps' => { 'content-available' => 1 }
      )
    end

    it 'should create a dictionary only with mutable-content' do
        expect(Houston::Notification.new(mutable_content: true).payload).to eq(
          'aps' => { 'mutable-content' => 1 }
        )
    end

    it 'should allow custom data inside aps key' do
      notification_options = { :badge => 567, 'aps' => { 'loc-key' => 'my-key' } }
      expect(Houston::Notification.new(notification_options).payload).to eq(
        'aps' => { 'loc-key' => 'my-key', 'badge' => 567 }
      )
    end

    it 'should create notification from hash with string and symbol keys' do
      notification_options = { badge: 567, aps: { 'loc-key' => 'my-key' } }
      expect(Houston::Notification.new(notification_options).payload['aps']).to eq(
        'loc-key' => 'my-key', 'badge' => 567
      )
    end
  end

  describe '#sent?' do
    it 'should be false initially' do
      expect(subject.sent?).to be_falsey
    end

    it 'should be true after marking as sent' do
      subject.mark_as_sent!
      expect(subject.sent?).to be_truthy
    end

    it 'should be false after marking as unsent' do
      subject.mark_as_sent!
      subject.mark_as_unsent!
      expect(subject.sent?).to be_falsey
    end
  end

  describe '#message' do
    it 'should create a message with command 2' do
      command, _1, _2 = subject.message.unpack('cNa*')
      expect(command).to eq(2)
    end

    it 'should create a message with correct frame length' do
      _1, length, _2 = subject.message.unpack('cNa*')
      expect(length).to eq(211)
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
      expect(parse_items(items_stream).size).to eq(5)
    end

    it 'should include an item #1 with the token as hexadecimal' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      expect(items).to include([1, 32, ['ce8be6272e43e85516033e24b4c289220eeda4879c477160b2545e95b68b5969'].pack('H*')])
    end

    it 'should include an item #2 with the payload as JSON' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      expect(items).to include([2, 155, '{"key1":1,"key2":"abc","aps":{"alert":"Houston, we have a problem.","badge":2701,"sound":"sosumi.aiff","category":"INVITE_CATEGORY","content-available":1}}'])
    end

    it 'should include an item #3 with the identifier' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      expect(items).to include([3, 4, [42].pack('N')])
    end

    it 'should include an item #4 with the expiry' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      expect(items).to include([4, 4, [1234567890].pack('N')])
    end

    it 'should include an item #5 with the priority' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      expect(items).to include([5, 1, [10].pack('c')])
    end

    it 'should pad or truncate token so it is 32 bytes long' do
      notification_options[:token] = '<ce8be627 2e43e855 16033e24 b4c28922>'
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      expect(items).to include([1, 32, ['ce8be6272e43e85516033e24b4c2892200000000000000000000000000000000'].pack('H*')])
    end

    it 'might be missing the identifier item' do
      notification_options.delete(:id)
      notification = Houston::Notification.new(notification_options)
      msg = notification.message
      _1, _2, items_stream = notification.message.unpack('cNa*')
      items = parse_items(items_stream)
      expect(items.size).to eq(4)
      expect(items.find { |item| item[0] == 3 }).to be_nil
    end

    it 'might be missing the expiry item' do
      notification_options.delete(:expiry)
      notification = Houston::Notification.new(notification_options)
      msg = notification.message
      _1, _2, items_stream = notification.message.unpack('cNa*')
      items = parse_items(items_stream)
      expect(items.size).to eq(4)
      expect(items.find { |item| item[0] == 4 }).to be_nil
    end

    it 'might be missing the priority item' do
      notification_options.delete(:priority)
      notification = Houston::Notification.new(notification_options)
      msg = notification.message
      _1, _2, items_stream = notification.message.unpack('cNa*')
      items = parse_items(items_stream)
      expect(items.size).to eq(4)
      expect(items.find { |item| item[0] == 5 }).to be_nil
    end
  end

  describe '#error' do
    context 'a status code has been set' do
      it 'returns an error object mapped to that status code' do
        status_code = 1
        notification = Houston::Notification.new(notification_options)
        notification.apns_error_code = status_code
        expect(notification.error.message).to eq(Houston::Notification::APNSError::CODES[status_code])
      end
    end

    context 'a status code has been set to 0' do
      it 'returns nil' do
        status_code = 0
        notification = Houston::Notification.new(notification_options)
        notification.apns_error_code = status_code
        expect(notification.error).to be_nil
      end
    end

    context 'a status code has not been set' do
      it 'returns nil' do
        notification = Houston::Notification.new(notification_options)
        expect(notification.error).to be_nil
      end
    end
  end
end
