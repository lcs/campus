#!/usr/bin/env ruby
# encoding: UTF-8
#
# server_1

require 'em-websocket'
require "./objects.rb"
require 'logger'
require 'yaml'
require 'json'
require 'cgi'
require './motd.rb'
# key is person object, value is connection
CONNECTION_MAP = {}

LOG = Logger.new(STDOUT)
snapdir = "snapshots"
Dir.mkdir(directory_name) unless File.exists?(snapdir)

snapshots = Array.new
Dir.new(snapdir).entries.each { |n| snapshots.push(snapdir + "/" + n) if File.file?(snapdir + "/" + n) }
snapshots = snapshots.sort_by {|filename| File.mtime(filename) }

if snapshots.any?
  File.open(snapshots.last) do |file|
    puts "Loading #{file}:\n"
    data = Marshal.load(file)
    puts data.inspect
    WorldObject.load(data) 
  end
else
  WorldObject.load []
end

starting_place = ObjectSpace.each_object(WorldObject).select {|o| o.name == "The Oobliette" }
starting_place = [Place.new] unless starting_place.any?
NOWHERE = starting_place.first

EventMachine.run {

  EventMachine::WebSocket.start(:host => "baby-vm.dhcp.mathworks.com", :port => 33334, :debug => true) do |ws|

    ws.onopen do
      WorldHandler.go(ws)
    end

    ws.onmessage do |msg|
      WorldHandler.go(ws, msg)
    end

    ws.onclose do
      ws.person.location.people.each{ |p| CONNECTION_MAP[p].send colorize("#{ws.person.name} has disconnected.", "response alert") unless CONNECTION_MAP[p].nil? }
      CONNECTION_MAP.delete ws.person
    end

    ws.onerror   { |e| LOG.error "Error: #{e.message}\n#{e.backtrace}" }
  end

  puts "Server started..."
}
