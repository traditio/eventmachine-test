#coding = UTF-8
require 'socket'
require 'logger'
require 'json'
# data -> /tmp/socket_proxy.socket -> 127.0.0.1:9001 (delay N sec) -> /tmp/socket_proxy.socket -> console


$log = Logger.new($stderr)


class JsonClient

  SOCKET_TO_CONNECT = "/tmp/socket_proxy.socket"

  def connect
      @socket = create_socket
  end

  def process(data)
    unless @socket.nil?
      @socket.puts(data)
      line = @socket.gets
      begin
        response = JSON.load(line)
      rescue JSON::ParserError
        $log.error "Gets invalid JSON: #{line}."
        response = nil
      end
      @socket.close
      response
    else
      $log.error "Не выполнено подключение к сокету #{SOCKET_TO_CONNECT}."
      nil
    end
  end

  private

  def create_socket
    begin
      UNIXSocket.new(SOCKET_TO_CONNECT)
    rescue
      nil
    end
  end

end

if __FILE__==$0
  threads = []

  (0..5).each_with_index do |item, i|
      thread = Thread.new do
        c = JsonClient.new i
        (0..3).each do
          c.connect
          lines = c.process "{\"id\": #{item}, \"text\": \"client #{i} req #{item}\"}"
          puts "Client #{i} gets #{lines}." unless lines.nil?
        end
      end
      thread.run
      threads << thread
  end

  threads.each {|thread| thread.join}
end
