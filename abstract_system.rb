# coding: UTF-8
require 'eventmachine'
require 'json'
require 'logger'

$log = Logger.new($stdout)

module AbstractSystemHandler
  # Сервер абстрактной системы с произвольной задержкой перед выдачей ответа.
  # Принимает строки JSON {'id': ..., 'text': ...}
  # Отдает JSON {'id': ..., 'text': 'answ#{id}}'} с произвольной задержкой 0-2 секунды
  # Возвращает "!error: invalid JSON\n" если полученный JSON невалидный

  include EventMachine::Protocols::LineText2 # сервер принимает строки в качестве команд

  REQUIRED_KEYS = %w[id text] # ключи, которые должны быть в принимаемом JSON-е

  def receive_json(json)
    # обработка полученного json-а
    answer = JSON.dump({:id => json['id'], :text => "answ#{json['id']}"})
    $log.debug("AbstractSystemHandler #{self.hash}") {'Отправил #{answer}.'}
    send_data "#{answer}\n"
  end

  def receive_line(line)
    delay_sec = Random.rand(3)
    $log.debug("AbstractSystemHandler #{self.hash}") { "Принял #{line}." }
    $log.debug("AbstractSystemHandler #{self.hash}") { "Пауза #{delay_sec} секунд." }
    EM.add_timer(delay_sec) do # задержка на пару секунд. Это абстрактная система очень медленнная...
      begin
        json = JSON.load(line)
        raise unless REQUIRED_KEYS.all? { |i| json.has_key? i }
      rescue # сообщение об ошибке
        $log.debug("AbstractSystemHandler #{self.hash}") {'Ошибка.'}
        send_data "!error: invalid JSON\n"
      else # обработка данных и ответ
        receive_json json
      ensure
        close_connection # обязательно закрываем соединение
      end
    end
  end
end

trap('SIGINT') { # правильно выходим по ctrl-c
  puts 'Принудительное завершение!'
  EM.stop_event_loop
  exit(0)
}

EM.run {
  ip, port = '127.0.0.1', '9001'
  puts "Запуск сервера абстрактной системы #{ip}:#{port}."
  EM::start_server ip, port, AbstractSystemHandler
}

puts 'Остановка сервера абстрактной системы.'
