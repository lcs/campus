#!/usr/bin/env ruby
#
# server_1

require "./objects.rb"
require 'eventmachine'
require 'logger'

LOG = Logger.new("server.log")
NOWHERE = Place.new

module WorldServer
  
  def self.save
    File.open("database.dat","w") do |file|
      Marshal.dump(WorldObject.everything,file)
    end
  end

  def post_init
    if File.exists?("database.dat")
      File.open("database.dat") do |file|
        WorldObject.load(Marshal.load(file)) 
      end
    end
    @me = Person.new(NOWHERE, self)
  end
  
  def become(person)
    WorldObject.everything.delete @me
    @me.location.people.delete @me
    @me = person
  end
  
  def receive_data data
    begin
      WorldServer.save and return if data == "save"
      response = @me.send(:process_command, data)
      send_data response + "\n" unless response.nil?
    rescue Exception => e
      LOG.error e.message + e.backtrace
      send_data "\n\nTHAT WAS A BAD ERROR!\n\n"
    end
  end

  def unbind
    @me.location.people.delete @me
    @me.location.people.each{ |p| p.connection.send_data "#{@me.name} has disconnected.\n" }
    @me.connection = nil
  end  
end

EventMachine::run {
  EventMachine::start_server "baby-vm.dhcp.mathworks.com", 33333, WorldServer
  puts 'running world server on 33333'
}