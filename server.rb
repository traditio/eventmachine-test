#coding = UTF-8
require "eventmachine"
require "json"
require 'logger'
require "socket"


$log = Logger.new($stdout)


module ServerConnection
  # Сервер. Слушает unix domain socket. Принимает строки.
  # Ставит эти строки в глобальную очередь запросов.
  # После того как эта очередь выполняет запрос, возвращает ответ клиенту.
  include EventMachine::Protocols::LineText2

  def initialize(queue)
    @queue = queue
  end

  def receive_line(line)
    $log.debug("ServerConnection #{self.hash}") { "добавил в очередь." }
    @queue.push([self, line])
  end

  def process_async_result(result)
    # Выполнился запрос в глобальной очереди. Вернуть результат.
    # Каждый раз, когда мы возвращаем ответ, мы отключаемся.
    # Иначе клиенту придется реализовывать "разбор полетов" - на какую именно команду
    # вернулся ответ.
    $log.debug("ServerConnection #{self.hash}") { "получил результат." }
    send_data "#{result}\n"
    close_connection_after_writing
  end
end


module RequestDataFromAbstractSystem
  # Запрос на удаленную абстрактную систему.
  include EventMachine::Protocols::LineText2

  TIME_TO_RETRY = 1 # сек

  def initialize(request, queue)
    @client, @request = request[0], request[1]
    @queue = queue
    @response = nil
  end

  def connection_completed
    $log.debug("RequestDataFromAbstractSystem #{self.hash}") { "оправил #{@request}." }
    send_data "#{@request.chomp}\n"
  end

  def receive_line(line)
    $log.debug("RequestDataFromAbstractSystem #{self.hash}") { "получил #{line}." }
    @response = line
    @client.process_async_result @response
    close_connection_after_writing
  end

  def unbind
    # Удаленная абстрактная система не вернула ответ. Попытаемся снова через N сек.
    if @response.nil?
      $log.error("RequestDataFromAbstractSystem #{self.hash}") {
        "сервер закрыл соединение без ответа. Возврат в очередь через #{TIME_TO_RETRY} сек."
      }
      add_timer(TIME_TO_RETRY) { @queue.push([@client, @request]) }
    end
  end

  private

  def add_timer(sec, &block)
    EM.add_timer(TIME_TO_RETRY, block)
  end
end


class ProcessQueue
  def initialize(options, queue)
    @options = options
    @queue = queue
  end

  def process
    process_queue = Proc.new {
      @queue.pop do |connection|
        $log.debug("process_queue") { "взял из очереди." }
        # выполняем запрос на удаленную абстрактную систему
        connect connection
        plan_on_next_tick process_queue
      end
    }
  end

  private

  def connect(connection)
    EM.connect @options[:ip], @options[:port], RequestDataFromAbstractSystem, connection, @queue
  end

  def plan_on_next_tick(block)
    EM.next_tick(block)
  end
end


if __FILE__==$0

  trap('SIGINT') {# правильно выходим по ctrl-c
    puts 'Принудительное завершение!'
    EM.stop_event_loop
    exit(0)
  }


  EM.run {

    unix_domain_socket = "/tmp/socket_proxy.socket"

    queue = EM::Queue.new # глобальная очередь запросов

    EM::start_unix_domain_server unix_domain_socket, ServerConnection, queue
    puts "Запуск сервера на #{unix_domain_socket}."
    puts "Для тестирования в консоли используйте rlwrap nc -U #{unix_domain_socket}.\n"

    # асинхронная обработка глобальной очереди запросов
    process_queue = ProcessQueue.new({:ip =>  "127.0.0.1", :port => 9001}, queue).process
    EM.next_tick(process_queue)
  }

  puts "Остановка сервера."
end
