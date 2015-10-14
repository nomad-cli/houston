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

  notification.alert = "Ilya test #{i}"
  notification.badge = 1
  notification.sound = "sosumi.aiff"
  notification.category = "INVITE_CATEGORY"
  # notification.content_available = true
  # notification.custom_data = {foo: "bar"}

  notification_array << notification
end

apn.capture_exceptions do |e|
  puts "* Exception! #{e.class.name}: #{e}"
end

# failed_notifications = Manager.push(APN, notification_array)
progress = 0
teller = Thread.new{ loop{ sleep 1; puts "Progress: #{progress}, #{(progress*100.0/notification_array.size).round}%" } }
failed_notifications = apn.push(notification_array.freeze) {|index| progress = index }
teller.kill
puts "Done: #{progress}, #{(progress*100.0/notification_array.size).round}%"
puts "failed #{failed_notifications.size}: #{failed_notifications.map{|n| n.token }.join(', ')}"

puts "Validating count against server:"
connection = apn.get_connection
test_notification = Houston::Notification.new(token: "666")
connection.write(test_notification.message)
good, bad = connection.read.unpack('NN')
connection.close
real_bad = failed_notifications.size
real_good = notification_array.size - real_bad
puts "Good: #{good}=#{real_good} #{good==real_good ? 'OK' : 'FAIL'}"
puts "Bad: #{bad}=#{real_bad} #{bad==real_bad ? 'OK' : 'FAIL'}"

# APN.push(notification_array)
# puts failed_notifications
# logger = Logger.new("houston_test.log", 'daily')
# logger.info("finished after #{Time.now - beginning}")
