require_relative 'apn_parser'
require 'socket'
require 'openssl'

# Module that creates TCP server that mocks apple server
# It accepts any amount of connections on given port (default 2195)
# Reads notification messages until EOF or notification with token that starts with "bad"
# If it met notification with "bad", it sends apple protocol error response (code 8 - invalid token) and immediately closes connection
# The message format IS NOT checked, if size field is less than actual message size it will wait forever.
# If you want to run it directly from command line:
#   ruby mock_server.rb run
module MockServer
  #reads notifications from socket until EOF or bad token (starts with "bad")
  def self.read(socket, id)
    puts "#{id}. Client connected from #{socket.addr}"
    while !socket.eof?
      res = APNParser.read(socket)
      case res[:token][0,3]
      when "bad"
        socket.write([2,8,res[:id]].pack('ccN'))
        puts "#{id}. Bad: #{res[:id]}, #{res[:token]}"
        @bad_count += 1
        break
      when "666"
        puts "#{id}. Test get counts: good=#{@good_count}, bad=#{@bad_count}"
        socket.write([@good_count, @bad_count].pack('NN'))
        @good_count = @bad_count = 0
        break
      else
        puts "#{id}. Good: #{res[:id]}, #{res[:token]}"
        @good_count += 1
      end
    end
  ensure
    puts "#{id}. Closing"
    begin
      socket.close
    rescue => e
      puts "#{id}. Error closing: #{e}"
    end
  end

  #runs the server. reads notifications from any number of connections in separate threads
  def self.run(port=2195)
    threads = []
    server = TCPServer.new(port)
    sslContext = OpenSSL::SSL::SSLContext.new
    sslContext.cert = OpenSSL::X509::Certificate.new(File.open("test.pem"))
    sslContext.key = OpenSSL::PKey::RSA.new(File.open("test.pem"), 'push')
    sslServer = OpenSSL::SSL::SSLServer.new(server, sslContext)
    cur_id = 0

    puts "Started server on #{port}"
    @good_count = @bad_count = 0
    loop do
      cur_id += 1
      client = sslServer.accept
      threads << Thread.new(client, cur_id){|socket, id| read(socket, id) }
    end
  ensure
    threads.each{|t| t.kill }
    server.close
    puts "Got #{@good_count} good and #{@bad_count} bad notifications, totally #{@good_count+@bad_count}"
  end
end

MockServer.run if ARGV[0] == "run"
