# coding: UTF-8
# rspec -fd -c ./abstract_system_spec.rb
require "rspec"
require "rr"

require "../server.rb"


$log = Logger.new(nil) # подавить вывод логов в консоль


module RR::Adapters::RRMethods
  # https://github.com/btakita/rr/issues/49
  def rrsatisfy(&block)
    RR::WildcardMatchers::Satisfy.new(block)
  end
end


RSpec.configure do |config|
  config.mock_with :rr
end


#--- mocks and classes that extending modules for test


class EMQueueMock < Queue
  def pop(&block)
    block.call
    super
  end
end


class ServerConnectionClass
  include ServerConnection
end


class RequestDataFromAbstractSystemClass
  include RequestDataFromAbstractSystem

  def add_timer(sec, &block)
    block.call
  end
end


describe ServerConnection do
  before(:each) do
    @q = EMQueueMock.new
    @connection = ServerConnectionClass.new(@q)
  end

  it "ставит принятые строки в глобальную очередь" do
    line = "line"
    mock(@q).push(rrsatisfy {|arg| arg.kind_of? Array and arg.length == 2})
    @connection.receive_line line

  end

  it "коллбэк отсылает принятый результат клиенту и закрывает соединение" do
    result = ""
    mock(@connection).send_data "#{result}\n"
    mock(@connection).close_connection_after_writing
    @connection.process_async_result result
  end
end


describe RequestDataFromAbstractSystem do
  before do
    @q = EMQueueMock.new
    @client = Object.new
    @request = RequestDataFromAbstractSystemClass.new [@client, ""], @q
    mock(@request).close_connection_after_writing.any_number_of_times
  end

  context "когда получил от асбтрактной системы ответ" do

    it "перенаправляет его на коллбэк ServerConnection" do
      line = "some line"
      mock(@client).process_async_result(line)
      @request.receive_line(line)
    end
  end

  context "когда не получил от асбтрактной системы ответ" do
    it "добавляет запрос повторно в очередь" do
      mock(@q).push([@client, ""])
      @request.unbind
    end

  end
end


describe ProcessQueue do
  before do
    @options = {:ip => "127.0.0.1", :port => 9001}
    @q = EMQueueMock.new
    @process_queue = ProcessQueue.new @options, @q
  end

  context "когда есть элемент в очереди" do

    it "соединяется с абстрактной системой и планирует выборку из очереди на следующую итерацию реактора" do
      @q.push("el")
      mock(@process_queue).connect(anything)
      mock(@process_queue).plan_on_next_tick(is_a(Proc))
      @process_queue.process.call
      @q.should be_empty
    end

  end
end

