require 'yaml'
require 'active_support/core_ext/string'

def colorize(line, css_class="response normal")
  %[#{line}]
end

class ResponseArray < Array
end

class WorldHandler

  def self.create_response(text="I am a response.", type="info")
    {:text => text, :type => type}.to_json
  end

  def respond
    ResponseArray.new
  end

  def self.motd
    create_response("#{MOTD}", "system")
  end

  def self.who_are_you
      challenge = %[Who are you? (Type 'visitors' to see a list of previous visitors.)]
      create_response(challenge, "system")
  end

  def self.visitors
    resp = %[#{WorldObject.everything.select {|o| o.is_a?(Person)}.sort{|a,b| a.name <=> b.name}.join(", ")}]
    resp = "There are no previous visitors." if resp.blank?
    create_response resp, "info"
  end

  def self.create_person(ws, name)
    ws.person = Person.new(NOWHERE)
    ws.person.name = name
    CONNECTION_MAP[ws.person] = ws
    ws.identified = true
    str = "#{name} (a Person object) has been temporarily created and your connection is attached as #{name}.\nType 'help' for an explanation of what you can do here."
    create_response(str, "system")
  end

  def self.attach(ws, user)
    if CONNECTION_MAP[user].nil?
      ws.person = user
      CONNECTION_MAP[user] = ws
      ws.identified = true
      str = "You are attached as #{user.name}."
      create_response(str, "system")
    else
      create_response("That user is already attached. Try again.", "system")
    end
  end

  def self.go(ws, msg=nil)
    begin
      if msg.nil?
        ws.identified = false
        ws.send motd
        ws.send who_are_you
      else
        if ws.identified
          responses = ws.person.instance_eval(msg)
          if responses.is_a? ResponseArray
            responses.each {|r| ws.send r} 
          else
            ws.send create_response(responses.inspect, "info")
          end
        else
          if msg == "visitors"
            ws.send visitors
            ws.send who_are_you
          else
            login = WorldObject.everything.select {|o| o.is_a?(Person) && o.name == msg }
            if login.size > 1
              LOG.error %{ERROR: Name duplicate found for #{msg}.}
              raise "Errcode:HEEZAPONG! There are multiple Person objects with that name in the system.\nError logged.\nTalk to an admin to resolve, or log in as someone else and fix the name duplication."
            elsif login.size == 0
              ws.send create_person(ws, msg)
            else
              ws.send attach(ws, login.first)
            end
          end
        end
      end
    rescue Exception => e
      LOG.error e.inspect.to_s + "\n" + e.message + "\n" + e.backtrace.join("\n")
      str = %[Errcode:GLARG! #{msg} - #{e.message}\n#{e.backtrace.join("\n")}]
      ws.send create_response(str, "system")
    end
  end
end

class WorldObject
  attr_accessor :name, :description, :behaviors

  def self.const_missing(name)
    name.to_s
  end

  def create_response(text="I am a repsonse.", type="info")
    {:text => text, :type => type}.to_json
  end

  def help(args=[])
    word, block = *args 
    
    if word.nil?
      @help 
    else
      ref_array = local_ref(word)
      if ref_array.size == 1
        ref_array.first.help
      else
        "Which item do you mean? #{ref_array.join(', ')}"
      end
    end
  end
  

  def initialize
    raise "Wait! The name '#{self.name}' is already in use! Sorry. Try specifying another :name on creation." if WorldObject.everything.find {|o| o.name == self.name}
    WorldObject.everything << self
    @behaviors = {}
    @help = "I'm helptext for this object!"
  end
  
  def orphans
    ObjectSpace.each_object(WorldObject).to_a - WorldObject.everything
  end
  
  def update_behavior(key, code)
    self.behaviors[key] = code
    self.clear_behaviors
    self.reload_behaviors
  end

  def connect_orphans
    WorldObject.everything += orphans
  end
  
  def boot_the_sleepers
    orig = sleepers
    sleepers.each do |s|
      if s.is_bootable
        WorldObject.everything.delete s
        s.location.people.delete s
      end
    end
    (orig - sleepers).to_s + " have been booted."
  end
  
  def sweep
    orig = things
    things.each do |s|
      if s.is_sweepable
        WorldObject.everything.delete s
        s.location.items.delete s
      end
    end
    (orig - things).to_s + " have been swept."
  end

  def self.everything
    @all_objects ||= []
  end
    
  def self.load(data)
    data.each {|o| o.behaviors.values.each {|b| o.class_eval(b)}}
    @all_objects = data unless data.nil?
  end
  
  def reload_behaviors
    self.behaviors.values.each {|b| self.class_eval b}
  end

  def clear_behaviors
    self.singleton_methods.each {|m| self.class_eval {remove_method m} }
  end
  
  def sleepers
    WorldObject.everything.select {|o| o.is_a?(Person) && CONNECTION_MAP[o].nil? }
  end

  def people
    WorldObject.everything.select {|o| o.is_a?(Person) && !CONNECTION_MAP[o].nil? }
  end
  alias :who :people

  def places
    WorldObject.everything.select {|o| o.is_a?(Place)}
  end

  def things
    WorldObject.everything.select {|o| o.is_a?(Thing)}
  end
  
  def display(object)
    "#{object.name}
    #{object.description}"
  end
  
  def everything
    WorldObject.everything
  end
    
  def local_ref(args)
    name, block = *args 
    found = []
    found += items.select {|i| i.name == name}
    found += @location.items.select {|i| i.name == name}
    found += @location.people.select {|i| i.name == name}
    if found.size == 1
      found.first
    else
      found
    end
  end
  
  def world_ref(args)
    name, block = *args 
    ObjectSpace.each_object(WorldObject).select {|o| o.name == name }
  end  

  def WorldObject.save(by_who)
    WorldObject.everything.each{|o| o.clear_behaviors}
    File.open("snapshots/snapshot_#{Time.new.strftime('%m%d_%H%M_%S')}.dat","w") do |file|
      Marshal.dump(WorldObject.everything,file)
    end
    WorldObject.everything.each{|o| o.reload_behaviors}
    LOG.info "#{by_who} saved the world."
    CONNECTION_MAP.each {|k,v| k.tx "#{by_who} saved the world.", "response alert"}
    "Save complete."
  end  
end
  
class Place < WorldObject

  attr_accessor :exits, :items, :people, :key

  def initialize(options = {})
    self.name = options[:name] || "The Oobliette"
    self.key = @name.titleize.gsub(/[^a-zA-Z0-9]/, "").underscore rescue "key_#{rand(99999999)}"
    self.description = options[:description] || "A blank place. Dark and void. They can be found wherever the light fades."
    self.exits = {}
    self.items = []
    self.people = []
    raise "Wait! The key '#{@key}' is already in use in THIS location! Sorry. Try specifying another :key on creation." if self.exits.keys.include?(@key)
    super()
  end  
  
  def commands(args=[])
    self.class.instance_methods(false).sort.to_s
  end

  def attributes(args=[])
    self.instance_variables.sort.to_s
  end  

end

class Person < WorldObject
  attr_accessor :items, :location, :is_bootable
  
  def save
    WorldObject.save(self)
  end
  
  def exit
    @location.people.each {|p| p.tx "#{@name} disconnects.", "response alert"}
    tx("You leave. Come back again!")
    CONNECTION_MAP[self].close_connection_after_writing
  end
  alias :bye :exit
  
  def initialize(location)
    @is_bootable = true
    @location = location
    @location.people << self
    @name = "Guest-#{rand(999999)}"
    @description = "I am a faceless person. I should edit my description attributes to become more real (virtually.)"
    @items = []
    super()
  end
  
  def here
    self.location
  end
  
  def connect(place)
    self.location.exits[place.key] = place
    place.exits[self.location.key] = self.location
    "Connected!"
  end
    
  def tx(message="", css_class="response normal")
    CONNECTION_MAP[self].send colorize(message, css_class) unless CONNECTION_MAP[self].nil?
  end

  def look(args=nil)
    name, block = *args 
    if args.nil?
      ra = ResponseArray.new
      ra << create_response("#{self.location.name}","title")
      ra << create_response("#{self.location.description}","info")
      ra << create_response("Exits: #{self.location.exits.keys}","info")
      ra << create_response("Occupants: #{self.location.people}","info")
      ra
    else
      examine(name)
    end
  end  
  
  def to_s(inspect=false)
    string = @name
    string += " (sleeping)" unless CONNECTION_MAP[self]
    string
  end
    
  def attributes
    self.instance_variables.sort.to_s
  end  

  def use_exit(args)
    key, block = *args 
    new_location = @location.exits[key]
    if new_location.nil?
      "I don't see that exit."
    else
      has_left @location
      @location = new_location
      @location.people.each {|p| p.tx "#{@name} joins you.", "response alert"}
      @location.people << self
      self.look
    end
  end

  def goto(args)
    item, block = *args 
    target = WorldObject.everything.find {|i| (i.name == item)}
    if target.nil?
      "I don't see that person/thing."
    else
      if target.is_a? Place
        has_bamfed @location
        @location = target
      elsif target.respond_to? :location
        has_bamfed @location
        @location = target.location
      else
        LOG.error "Invalid goto target: #{item}"
        return "Not much happens since the thing you're targeting isn't a place and doesn't respond to :location. Weird? Tell an admin!"
      end
      @location.people.each {|p| p.tx "BAMF! #{@name} arrives in a cloud of acrid smoke!", "response alert" }
      @location.people << self
      "...BAMF!..." + @location.look
    end
  end
  
  def examine(args)
    thing, block = *args 
    object = local_ref(thing)
    return "There is no #{thing} at this location." if object.size == 0
    object.size == 1 ? display(object.first) : "Dammit, I can't figure out which one you mean!"
  end  
  
  def say(args)
    words, block = *args 
    (@location.people - [self]).each{ |p| p.tx "[[;#AEF;#000]#{self.name}: \"#{words}\"]" }
    nil
  end
  alias :s :say
  
  def emote(args)
    action, block = *args 
    (@location.people - [self]).each{ |p| p.tx "[[i;#8BF;#000]#{self.name} #{action}]" }
    "#{self.name} #{action}"
  end
  alias :e :emote
  
  def method_missing(m, *args, &block)
    return self.send(m, args, block) if self.respond_to? m
    return self.send(:use_exit, m.to_s) if @location.exits.keys.include? m.to_s
    self.items.each {|i| return i.send(m,args, block) if i.respond_to? m}
    self.location.items.each {|i| return i.send(m,args, block) if i.respond_to? m}
    (self.items + self.location.items + self.location.people + [self] + [self.location]).each {|i| return i.name if i.name == m }
    super
  end
  
  private
  
  def has_left(location)
    location.people.delete self
    location.people.each {|p| p.tx "#{@name} leaves...", "response alert"}
  end  

  def has_bamfed(location)
    location.people.delete self
    location.people.each {|p| p.tx "BAMF! #{@name} disappears...", "response alert"}
  end  

end

class Thing < WorldObject
  attr_accessor :name, :description, :is_sweepable

  def initialize(options={})
    @name = options[:name] || "A Thing"
    @description = options[:description] || "It feels like a thing."
    @is_sweepable = true
    super()
  end    

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

