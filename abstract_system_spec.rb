# coding: UTF-8
# rspec -fd -c ./abstract_system_spec.rb
require "rspec"
require "rr"

require "./abstract_system.rb"


$log = Logger.new(nil) # подавить вывод логов в консоль


RSpec.configure do |config|
  config.mock_with :rr
end


class AbstractSystemHandlerClass
  include AbstractSystemHandler

  def add_timer(delay, &block)
    block.call
  end

  def close_connection
  end

end


describe AbstractSystemHandler do

  let(:command) { {"id" => 1, "text" => "command 1"} }
  let(:conn) do
    conn = AbstractSystemHandlerClass.new
    stub(conn).send_data { |line| line }
    conn
  end

  it "сделать паузу перед отправкой сообщения клиенту" do
    mock(conn).add_timer(numeric)
    conn.receive_line("")
  end

  context "когда получает невалидный JSON" do

    it "отправить клиенту сообщение об ошибке" do
      conn.receive_line("invalid").should eql("!error: invalid JSON\n")
    end

    it "закрыть соединение" do
      mock(conn).close_connection
      conn.receive_line("invalid")
    end

  end

  context "когда получает валидный JSON" do

    it "#receive_json" do
      stub(conn).send_data { |line| line }
      mock(conn).receive_json(command)
      conn.receive_line(JSON.dump(command))
    end

    it "послать ответ клиенту" do
      mock(conn).send_data("#{JSON.dump({:id => 1, :text => "answ1"})}\n").times(1)
      conn.receive_line(JSON.dump(command))
    end

    it "закрыть соединение" do
      mock(conn).close_connection
      conn.receive_line("invalid")
    end

  end

end