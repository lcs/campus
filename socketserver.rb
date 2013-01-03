#!/usr/bin/env ruby
# encoding: UTF-8
#
# server_1

require 'em-websocket'
require "./objects.rb"
require 'logger'
require 'yaml'
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

def colorize(line, css_class="response normal")
  line.blank? ? line.inspect : %[#{line}]
end

EventMachine.run {

  EventMachine::WebSocket.start(:host => "baby-vm.dhcp.mathworks.com", :port => 33334, :debug => true) do |ws|

    ws.onopen do
      LOG.info ws.inspect
      ws.identified = false
      response = %[#{MOTD}\n\nWho are you? (Type 'visitors' to see a list of previous visitors.)]
      ws.send(colorize(response))
    end

    ws.onmessage do |msg|
      if ws.identified
        response = begin
          colorize(ws.person.instance_eval msg)
        rescue Exception => e
          LOG.error msg + "\n" + e.inspect.to_s + "\n" + e.message + "\n" + e.backtrace.join("\n")
          str = %[[[;#f55;#000]Errcode:GLARG! #{msg} - #{e.message}]\n#{e.backtrace.join("\n")}]
          colorize(str,"response error")
        end

        begin
          ws.send response
        rescue Exception => e
          LOG.error e.message + e.backtrace.join("\n")
          ws.send colorize("THAT WAS A BAD ERROR! Check the server log for that one. I can't recover.", "response error")
        end
      else
        if msg == "visitors"
          resp = %[#{WorldObject.everything.select {|o| o.is_a?(Person)}.sort{|a,b| a.name <=> b.name}.join("\n")}]
          resp = "There are no previous visitors." if resp.blank?
          ws.send resp
          prompt_again = %[And who are you?]
          ws.send(colorize(prompt_again))
        else
          login = WorldObject.everything.select {|o| o.is_a?(Person) && o.name == msg }
          LOG.info login
          response = if login.size > 1
            LOG.error %{ERROR: Name duplicate found for #{msg}.}
            str = "Errcode:HEEZAPONG! There are multiple Person objects with that name in the system.\nError logged.\nTalk to an admin to resolve, or log in as someone else and fix the name duplication."
            colorize(str, "response alert")
          elsif login.size == 0
            ws.person = Person.new(NOWHERE)
            ws.person.name = msg
            CONNECTION_MAP[ws.person] = ws
            ws.identified = true
            str = "#{msg} (a Person object) has been temporarily created and your connection is attached as #{msg}.\nType 'help' for an explanation of what you can do here."
            colorize(str, "response alert")
          else
            user = login.first
            if CONNECTION_MAP[user].nil?
              ws.person = user
              CONNECTION_MAP[user] = ws
              ws.identified = true
              str = "You are attached as #{msg}.\n \n#{ws.person.instance_eval("look")}"
              colorize(str, "response alert")
            else
              colorize("That user is already attached. Try again.", "response alert")
            end

          end
          ws.send(response)
        end
      end
    end

    ws.onclose do
      ws.person.location.people.each{ |p| CONNECTION_MAP[p].send colorize("#{ws.person.name} has disconnected.", "response alert") unless CONNECTION_MAP[p].nil? }
      CONNECTION_MAP.delete ws.person
    end

    ws.onerror   { |e| LOG.error "Error: #{e.message}\n#{e.backtrace}" }
  end

  puts "Server started..."
}
