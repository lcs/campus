#!/usr/bin/env ruby
# encoding: UTF-8
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

def divify(line, css_class="response normal")
  %[<div class="line"><span class="#{css_class}">#{line}</span></div>]
end

EventMachine.run {

  EventMachine::WebSocket.start(:host => "localhost", :port => 33334, :debug => true) do |ws|

    ws.onopen do
      LOG.info ws.inspect
      ws.identified = false
      response = %[What is your name? (You will always use this to login.) <br/>Users:#{WorldObject.everything.select {|o| o.is_a?(Person)}.inspect}]
      ws.send(divify(response))
    end

    ws.onmessage do |msg|
      if ws.identified
        response = begin
          divify(ws.person.instance_eval msg)
        rescue Exception => e
          LOG.error msg + "\n" + e.inspect.to_s + "\n" + e.message + "\n" + e.backtrace.join("\n")
          str = %[Errcode:GLARG! #{msg} - <a href="#" onclick="$('#id-#{e.object_id}').toggle();">#{e.message}</a><br/><span id="id-#{e.object_id}" style="display:none;"><br/>#{e.backtrace.join("<br/>")}</span>]
          divify(str,"response error")
        end

        begin
          ws.send response
        rescue Exception => e
          LOG.error e.message + e.backtrace.join("\n")
          ws.send divify("THAT WAS A BAD ERROR! Check the server log for that one. I can't recover.", "response error")
        end
      else
        login = WorldObject.everything.select {|o| o.is_a?(Person) && o.name == msg }
        LOG.info login
        response = if login.size > 1
          LOG.error %{ERROR: Name duplicate found for #{msg}.}
          str = "Errcode:HEEZAPONG! There are multiple Person objects with that name in the system. Error logged. Talk to an admin to resolve, or log in as someone else and fix the name duplication."
          divify(str, "response alert")
        elsif login.size == 0
          ws.person = Person.new(NOWHERE)
          ws.person.name = msg
          CONNECTION_MAP[ws.person] = ws
          ws.identified = true
          str = "#{msg} has been temporarily created and you are logged in as #{msg}.<br/>Be sure to read the help section on saving your changes to the world."
          divify(str, "response alert")
        else
          user = login.first
          if CONNECTION_MAP[user].nil?
            ws.person = user
            CONNECTION_MAP[user] = ws
            ws.identified = true
            str = "You are logged in as #{msg}." 
            divify(str, "response alert")
          else
            divify("That user is already logged in. Try again.", "response alert")
          end

        end
        ws.send(response)
      end
    end

    ws.onclose do
      ws.person.location.people.each{ |p| CONNECTION_MAP[p].send divify("#{ws.person.name} has disconnected.", "response alert") unless CONNECTION_MAP[p].nil? }
      CONNECTION_MAP.delete ws.person
    end

    ws.onerror   { |e| LOG.error "Error: #{e.message}\n#{e.backtrace}" }
  end

  puts "Server started..."
}
