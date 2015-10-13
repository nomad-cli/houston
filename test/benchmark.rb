require_relative '../lib/houston/background_logger'
require_relative '../lib/houston/client'
require_relative '../lib/houston/connection'
require_relative '../lib/houston/notification'
# require_relative 'lib/houston/manager'

beginning = Time.now

# APN = Houston::Client.development
apn = Houston::Client.mock

notification_array = []

apn.certificate = File.read("test.pem")
apn.passphrase = "push"

num = (ARGV[0] || 1000).to_i
freq = (ARGV[1] || 50).to_i
num.times do |i|
  # Create a notification that alerts a message to the user, plays a sound, and sets the badge on the app
  token = rand(freq) == 0 ? "bad#{i}" : "acc#{i}"
  notification = Houston::Notification.new(token: token, expiry: 0, priority: 10)

  # notification.alert = (0...30).map { ('a'..'z').to_a[rand(10)] }.join
  # notification.alert = "Teste final AAPL - (Apple inc) test#{i} GE: Steadily Building Stamina - A Bullish Algorithmic Perspective"
  notification.alert = "Ilya test #{i}"
  notification.badge = 1
  notification.sound = "sosumi.aiff"
  notification.category = "INVITE_CATEGORY"
  # notification.content_available = true
  # notification.custom_data = {foo: "bar"}

  notification_array << notification
end

# failed_notifications = Manager.push(APN, notification_array)
failed_notifications = apn.push(notification_array) {|index| puts "progress: #{index}"}
puts "failed #{failed_notifications.size}: #{failed_notifications.map{|n| n.token }.join(', ')}"
# APN.push(notification_array)
# puts failed_notifications
# logger = Logger.new("houston_test.log", 'daily')
# logger.info("finished after #{Time.now - beginning}")
