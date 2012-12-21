#!/usr/bin/env ruby
#
# client_3

require 'eventmachine'
require 'readline'

class Client < EM::Connection
  attr_reader :queue

  def initialize(q)
    @queue = q

    cb = Proc.new do |msg|
      send_data(msg)
      q.pop &cb
    end

    q.pop &cb
  end

  def post_init
    send_data('look')
  end

  def receive_data(data)
    print data
  end
end

class KeyboardHandler < EM::Connection
  include EM::Protocols::LineText2

  attr_reader :queue

  def initialize(q)
    @queue = q
  end

  def receive_line(data)
    @queue.push(data)
  end
end

class ReadlineHandler
  def initialize(q)
    @queue = q
  end

  def get_input
    while buf = Readline.readline("", true)
      EventMachine.stop if buf == "exit"
      @queue.push buf
    end  
  end
end

EM.run {
  q = EM::Queue.new
  EM.connect('baby-vm.dhcp.mathworks.com', 33333, Client, q)

  readline_listener = EM::ThreadedResource.new do
    ReadlineHandler.new(q)
  end

  pool = EM::Pool.new

  pool.add readline_listener

  # Example where we care about the result:
  pool.perform do |dispatcher|
    # The dispatch block is executed in the resources thread.
    dispatcher.dispatch do |console|
      console.get_input
    end
  end
  
}