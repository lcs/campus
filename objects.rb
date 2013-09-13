require 'yaml'
require 'active_support/core_ext/string'
require_relative 'world_handler'
require_relative 'world_object'
require_relative 'place'
require_relative 'person'
require_relative 'thing'

def colorize(line, css_class="response normal")
  %[#{line}]
end

class ResponseArray < Array
end

class EventMachine::WebSocket::Connection
  attr_accessor :identified, :person, :is_sweepable

  def marshal_dump
    nil
  end

  def marshal_load array
    nil
  end  
end
