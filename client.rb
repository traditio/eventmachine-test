#coding = UTF-8
require 'socket'
# data -> /tmp/socket_proxy.socket -> 127.0.0.1:9001 (delay N sec) -> /tmp/socket_proxy.socket -> console

class Client

  def initialize(num)
    @num = num
  end

  def connect
    begin
      @socket = UNIXSocket.new("/tmp/socket_proxy.socket")
    rescue
      puts "Не могу подключиться к серверу."
      exit(1)
    end
  end

  def process(data)
    connect
    @socket.puts(data)
    while (line = @socket.gets) do
      puts "Client #{@num}: #{line}"
    end
    @socket.close
  end

end


threads = []

(0..5).each_with_index do |item, i|
    thread = Thread.new {
      c = Client.new i
      (0..3).each {
        c.process "{\"id\": #{item}, \"text\": \"client #{i} req #{item}\"}"
      }

    }
    thread.run
    threads << thread
end

threads.each {|thread| thread.join}

