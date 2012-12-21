#!/usr/bin/env ruby
#
# server_1

require 'em-websocket'
require "./objects.rb"
require 'logger'
require 'yaml'
require 'cgi'

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

  EventMachine::WebSocket.start(:host => "localhost", :port => 33334, :debug => true) do |ws|

    ws.onopen do
      LOG.info ws.inspect
      ws.identified = false
      ws.send "What is your name? (You will always use this to login.) <br/>Users:#{WorldObject.everything.select {|o| o.is_a?(Person)}.inspect}<br/>"
    end

    ws.onmessage do |msg|
      if ws.identified
        response = begin
          ws.person.instance_eval msg
        rescue Exception => e
          LOG.error msg + "\n" + e.inspect.to_s + "\n" + e.message + "\n" + e.backtrace.join("\n")
          %[Errcode:GLARG! #{msg} - <a href="#" onclick="$('#id-#{e.object_id}').toggle();">#{e.message}</a><br/><span id="id-#{e.object_id}" style="display:none;"><br/>#{e.backtrace.join("<br/>")}</span>]
        end

        begin
          ws.send (response.is_a?(String) ? response : CGI::escapeHTML(response.inspect))
        rescue Exception => e
          LOG.error e.message + e.backtrace.join("\n")
          ws.send "\n\nTHAT WAS A BAD ERROR!\n\n"
        end
      else
        login = WorldObject.everything.select {|o| o.is_a?(Person) && CONNECTION_MAP[o].nil? && o.name == msg }
        LOG.info login
        response = if login.size > 0
          LOG.error %{ERROR: Name duplicate found for #{msg}.}
          "Errcode:HEEZAPONG! There are multiple Person objects with that name in the system. Error logged. Talk to an admin to resolve, or log in as someone else and fix the name duplication."
        elsif login.size == 0
          ws.person = Person.new(NOWHERE)
          ws.person.name = msg
          CONNECTION_MAP[ws.person] = ws
          ws.identified = true
          "#{msg} has been temporarily created and you are logged in as #{msg}.<br/>Be sure to read the help section on saving your changes to the world."
        else
          ws.person = login.first
          CONNECTION_MAP[ws.person] = ws
          ws.identified = true
          "You are logged in as #{msg}." 
        end
        ws.send response
      end
    end

    ws.onclose do
      ws.person.location.people.each{ |p| CONNECTION_MAP[p].send "#{ws.person.name} has disconnected.\n" unless CONNECTION_MAP[p].nil? }
      CONNECTION_MAP.delete ws.person
    end

    ws.onerror   { |e| LOG.error "Error: #{e.message}\n#{e.backtrace}" }
  end

  puts "Server started on http://0.0.0.0:33334/"
}

