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
    it { should be_true }
  end

  describe '#custom_data' do
    subject { super().custom_data }
    it { should == { key1: 1, key2: 'abc' } }
  end

  describe '#truncation' do
    subject { super().truncation }
    it { should be_false }
  end

  describe '#omission' do
    subject { super().omission }
    it { should be Houston::Notification::DEFAULT_OMISSION }
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
      expect(subject.payload).to eq({
        'aps' => {
          'alert' => 'Houston, we have a problem.',
          'badge' => 2701,
          'sound' => 'sosumi.aiff',
          'content-available' => 1
        },
        :key1 => 1,
        :key2 => 'abc'
      })
    end

    it 'should create a dictionary of only custom data and empty aps' do
      expect(Houston::Notification.new(key1: 123, key2: 'xyz').payload).to eq({
        'aps' => {},
        :key1 => 123,
        :key2 => 'xyz'
      })
    end

    it 'should create a dictionary only with alerts' do
      expect(Houston::Notification.new(alert: 'Hello, World!').payload).to eq({
        'aps' => { 'alert' => 'Hello, World!' }
      })
    end

    it 'should create a dictionary only with badges' do
      expect(Houston::Notification.new(badge: '123').payload).to eq({
        'aps' => { 'badge' => 123 }
      })
    end

    it 'should create a dictionary only with sound' do
      expect(Houston::Notification.new(sound: 'ring.aiff').payload).to eq({
        'aps' => { 'sound' => 'ring.aiff' }
      })
    end

    it 'should create a dictionary only with content-available' do
      expect(Houston::Notification.new(content_available: true).payload).to eq({
        'aps' => { 'content-available' => 1 }
      })
    end

    it 'should allow custom data inside aps key' do
      notification_options = { :badge => 567, 'aps' => { 'loc-key' => 'my-key' } }
      expect(Houston::Notification.new(notification_options).payload).to eq({
        'aps' => { 'loc-key' => 'my-key', 'badge' => 567 }
      })
    end
  end

  describe '#sent?' do
    it 'should be false initially' do
      expect(subject.sent?).to be_false
    end

    it 'should be true after marking as sent' do
      subject.mark_as_sent!
      expect(subject.sent?).to be_true
    end

    it 'should be false after marking as unsent' do
      subject.mark_as_sent!
      subject.mark_as_unsent!
      expect(subject.sent?).to be_false
    end
  end

  describe '#message' do
    it 'should create a message with command 2' do
      command, _1, _2 = subject.message.unpack('cNa*')
      expect(command).to eq(2)
    end

    it 'should create a message with correct frame length' do
      _1, length, _2 = subject.message.unpack('cNa*')
      expect(length).to eq(182)
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
      expect(items).to include([2, 126, '{"key1":1,"key2":"abc","aps":{"alert":"Houston, we have a problem.","badge":2701,"sound":"sosumi.aiff","content-available":1}}'])
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

    it 'should include an item #4 with the priority' do
      _1, _2, items_stream = subject.message.unpack('cNa*')
      items = parse_items(items_stream)
      expect(items).to include([5, 1, [10].pack('c')])
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

  def create_payload(size)
    payload = {
      'aps' => {
        'alert' => '',
        'badge' => 2701
      }
    }

    tmp_size = payload.to_json.bytesize
    missing = size - tmp_size
    payload['aps']['alert'] = 'a' * missing

    payload
  end

  describe '#truncatable?' do
    context 'When alert is present' do
      it 'should be true' do
        payload = { 'aps' => { 'alert' => 'Houston, we have a problem.' } }
        expect(Houston::Notification.new.send(:truncatable?, payload)).to be true
      end
    end
    context 'When alert is an empty string' do
      it 'should be false' do
        payload = { 'aps' => { 'alert' => '' } }
        expect(Houston::Notification.new.send(:truncatable?, payload)).to be false
      end
    end
    context 'When alert is missing' do
      it 'should be false' do
        payload = { 'aps' => {} }
        expect(Houston::Notification.new.send(:truncatable?, payload)).to be false
      end
    end
  end

  describe '#truncate' do
    context 'When payload bytesize exceeds MAXIMUM_PAYLOAD_SIZE' do
      context 'and omission is "..."' do
        it 'should truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE + 1)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = '...'
          notification.send(:truncate, payload)
          expect(alert_length).to be > payload['aps']['alert'].length
        end
      end
      context 'and omission is nil' do
        it 'should truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE + 1)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = nil
          notification.send(:truncate, payload)
          expect(alert_length).to be > payload['aps']['alert'].length
        end
      end
      context 'and omission is empty string' do
        it 'should truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE + 1)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = ''
          notification.send(:truncate, payload)
          expect(alert_length).to be > payload['aps']['alert'].length
        end
      end
      context 'and omission is false' do
        it 'should truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE + 1)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = false
          notification.send(:truncate, payload)
          expect(alert_length).to be > payload['aps']['alert'].length
        end
      end
    end
    context 'When payload bytesize is equal to MAXIMUM_PAYLOAD_SIZE' do
      context 'and omission is "..."' do
        it 'should not truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = '...'
          notification.send(:truncate, payload)
          expect(alert_length).to eq payload['aps']['alert'].length
        end
      end
      context 'and omission is nil' do
        it 'should not truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = nil
          notification.send(:truncate, payload)
          expect(alert_length).to eq payload['aps']['alert'].length
        end
      end
      context 'and omission is empty string' do
        it 'should not truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = ''
          notification.send(:truncate, payload)
          expect(alert_length).to eq payload['aps']['alert'].length
        end
      end
      context 'and omission is false' do
        it 'should not truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = false
          notification.send(:truncate, payload)
          expect(alert_length).to eq payload['aps']['alert'].length
        end
      end
    end
    context 'When payload bytesize does not exceed MAXIMUM_PAYLOAD_SIZE' do
      context 'and omission is "..."' do
        it 'should not truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE - 1)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = '...'
          notification.send(:truncate, payload)
          expect(alert_length).to eq payload['aps']['alert'].length
        end
      end
      context 'and omission is nil' do
        it 'should not truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE - 1)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = nil
          notification.send(:truncate, payload)
          expect(alert_length).to eq payload['aps']['alert'].length
        end
      end
      context 'and omission is empty string' do
        it 'should not truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE - 1)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = ''
          notification.send(:truncate, payload)
          expect(alert_length).to eq payload['aps']['alert'].length
        end
      end
      context 'and omission is false' do
        it 'should not truncate the alert' do
          payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE - 1)
          alert_length = payload['aps']['alert'].length
          notification = Houston::Notification.new(truncation: true)
          notification.omission = false
          notification.send(:truncate, payload)
          expect(alert_length).to eq payload['aps']['alert'].length
        end
      end
    end
  end

  describe '#validate_alert_encoding' do
    context 'When alert is valid string' do
      it 'should return alert without change' do
        notification = Houston::Notification.new
        expect(notification.send(:validate_alert_encoding, 'Houston')).to eq 'Houston'
      end
    end
    context 'When alert is invalid UTF-8 string' do
      it 'should fix the enconding of alert' do
        notification = Houston::Notification.new
        expect(notification.send(:validate_alert_encoding, "Houston\xC5")).to eq 'Houston'
      end
    end
  end

  describe '#available_bytesize_for_alert' do

    let(:payload) do
      # bytesize of this payload is 33
      {
        'aps' => {
          'alert' => '',
          'badge' => 2701
        }
      }
    end

    let(:notification) { Houston::Notification.new }

    before(:each) do
      stub_const('Houston::Notification::MAXIMUM_PAYLOAD_SIZE', 100)
    end

    context 'When payload bytesize does not exceed MAXIMUM_PAYLOAD_SIZE' do
      context 'and omission is "..."' do
        it 'should return available bytesize for alert' do
          payload['aps']['alert'] = 'a'
          notification.omission = '...'
          # 64 = 100 - 33 - 3
          # 100 => max payload size
          # 33 => payload bytesize without alert
          # 3 => omission bytesize
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 64
        end
      end
      context 'and omission is empty string' do
        it 'should return available bytesize for alert' do
          payload['aps']['alert'] = 'a'
          notification.omission = ''
          # 67 = 100 - 33 - 0
          # 100 => max payload size
          # 33 => payload bytesize without alert
          # 0 => omission bytesize
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 67
        end
      end
      context 'and omission is nil' do
        it 'should return available bytesize for alert' do
          payload['aps']['alert'] = 'a'
          notification.omission = nil
          # 67 = 100 - 33 - 0
          # 100 => max payload size
          # 33 => payload bytesize without alert
          # 0 => omission bytesize
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 67
        end
      end
    end
    context 'When payload is equal to MAXIMUM_PAYLOAD_SIZE' do
      context 'and omission is "..."' do
        it 'should return available bytesize for alert' do
          payload['aps']['alert'] = 'a' * 67
          notification.omission = '...'
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 64
        end
      end
      context 'and omission is empty string' do
        it 'should return available bytesize for alert' do
          payload['aps']['alert'] = 'a' * 67
          notification.omission = ''
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 67
        end
      end
      context 'and omission is nil' do
        it 'should return available bytesize for alert' do
          payload['aps']['alert'] = 'a' * 67
          notification.omission = nil
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 67
        end
      end
    end
    context 'When payload exceeds MAXIMUM_PAYLOAD_SIZE' do
      context 'and omission is "..."' do
        it 'should return available bytesize for alert' do
          payload['aps']['alert'] = 'a' * 68
          notification.omission = '...'
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 64
        end
      end
      context 'and omission is empty string' do
        it 'should return available bytesize for alert' do
          payload['aps']['alert'] = 'a' * 68
          notification.omission = ''
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 67
        end
      end
      context 'and omission is nil' do
        it 'should return available bytesize for alert' do
          payload['aps']['alert'] = 'a' * 68
          notification.omission = nil
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 67
        end
      end
    end
    context 'When payload exceeds MAXIMUM_PAYLOAD_SIZE without alert' do
      context 'and omission is "..."' do
        it 'should return 0' do
          payload['custom'] = 'a' * 68
          notification.omission = '...'
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 0
        end
      end
      context 'and omission is empty string' do
        it 'should return 0' do
          payload['custom'] = 'a' * 68
          notification.omission = ''
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 0
        end
      end
      context 'and omission is nil' do
        it 'should return 0' do
          payload['custom'] = 'a' * 68
          notification.omission = nil
          expect(notification.send(:available_bytesize_for_alert, payload)).to be 0
        end
      end
    end
  end

  describe '#payload_valid?' do
    context 'When payload exceeds MAXIMUM_PAYLOAD_SIZE' do
      it 'should be false' do
        payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE + 1)
        expect(Houston::Notification.new.send(:payload_valid?, payload)).to be false
      end
    end
    context 'When payload does not exceed MAXIMUM_PAYLOAD_SIZE' do
      it 'should be true' do
        payload = create_payload(Houston::Notification::MAXIMUM_PAYLOAD_SIZE)
        expect(Houston::Notification.new.send(:payload_valid?, payload)).to be true
      end
    end
  end

  describe '#truncatable?' do
    context 'When payload has alert key' do
      context 'and alert is nil' do
        it 'should return false' do
         notification = Houston::Notification.new
         expect(notification.send(:truncatable?, { 'aps' => { 'alert' => nil } })).to be_false
        end
      end
      context 'and alert is empty string' do
        it 'should return false' do
         notification = Houston::Notification.new
         expect(notification.send(:truncatable?, { 'aps' => { 'alert' => '' } })).to be_false
        end
      end
      context 'and alert is present' do
        it 'should return true' do
         notification = Houston::Notification.new
         expect(notification.send(:truncatable?, { 'aps' => { 'alert' => 'Houston' } })).to be_true
        end
      end
    end
    context 'When payload does not have alert key' do
      it 'should return false' do
       notification = Houston::Notification.new
       expect(notification.send(:truncatable?, { 'aps' => {} })).to be_false
      end
    end
  end

end
