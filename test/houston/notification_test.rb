require_relative '../test_helper'

describe Houston::Notification do
  describe ".new" do
    it "accepts the standard APN paramaters and adds the rest to custom data" do
      now = Time.now
      n = Houston::Notification.new token: 'ABC',
                                    alert: 'Hi!',
                                    badge: 8,
                                    sound: 'wuff.aif',
                                    expiry: now,
                                    id: 42,
                                    content_available: 1,
                                    foo: 'foo',
                                    bar: 'bar'
      n.token.must_equal 'ABC'
      n.device.must_equal n.token
      n.alert.must_equal 'Hi!'
      n.badge.must_equal 8
      n.sound.must_equal 'wuff.aif'
      n.expiry.must_equal now
      n.content_available.must_equal 1
      n.id.must_equal 42
      n.custom_data.must_equal foo: 'foo', bar: 'bar'
    end
  end

  describe '#payload' do
    specify 'an empty payload' do
      n = Houston::Notification.new
      n.payload.must_equal({ 'aps' => {} })
    end

    specify 'with alert' do
      n = Houston::Notification.new alert: 'Hi!'
      n.payload.must_equal({ 'aps' => { 'alert' => 'Hi!' } })
    end

    specify 'with badge' do
       n = Houston::Notification.new badge: '8'
       n.payload.must_equal({ 'aps' => { 'badge' => 8 } })
    end

    specify 'with sound' do
      n = Houston::Notification.new sound: 'wuff.aif'
      n.payload.must_equal({ 'aps' => { 'sound' => 'wuff.aif' } })
    end

    specify 'with content-available' do
      n = Houston::Notification.new content_available: true
      n.payload.must_equal({ 'aps' => { 'content-available' => 1 } })
    end

    specify 'with custom data' do
      n = Houston::Notification.new foo: 'bar'
      n.payload.must_equal({:foo=>"bar", "aps"=>{}})
    end
  end

end