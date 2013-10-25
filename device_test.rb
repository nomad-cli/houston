$LOAD_PATH.unshift "./lib"
require "houston"

client = Houston::Client.development certificate: File.read('/Users/mlangenberg/Nedap/dev/milo-server/config/apn_certs/APN_CK_Development.pem'), passphrase: 'PF9o9qSozyJi'
n = Houston::Notification.new alert: 'YOLO!', device: '50c4da2b0140f577a204ecac0d90b0615d909fc14d5a109c1dc793421af8958f'
client.session { |s| s.push(n) }
puts "Notification sent"