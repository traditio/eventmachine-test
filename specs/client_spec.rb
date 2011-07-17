# coding: UTF-8
require "rspec"
require "rr"

require "../json_client.rb"


$log = Logger.new(nil) # подавить вывод логов в консоль


RSpec.configure do |config|
  config.mock_with :rr
end


describe JsonClient do
  before do
    @socket = Object.new
    @client = JsonClient.new
  end

  it "создает подключение к сокету" do
    mock(@client).create_socket { true }
    @client.connect.should be_true
  end

  context "получает невалидный json" do
    it "возвращает nil и отключается" do
      mock(@socket).puts is_a(String)
      mock(@socket).gets { "invalid json" }
      mock(@client).create_socket { @socket }
      mock(@socket).close
      @client.connect
      @client.process("123").should be_nil
    end
  end

  context "получает json" do
    it "серализует в хэш и отключается" do
      mock(@socket).puts is_a(String)
      mock(@socket).gets { '{"response": true}' }
      mock(@client).create_socket { @socket }
      mock(@socket).close
      @client.connect
      @client.process("123").should be_a_kind_of(Hash)
    end
  end
end