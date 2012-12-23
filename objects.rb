require 'yaml'
require 'active_support/core_ext/string'

def divify(line, css_class="response normal")
  %[#{line}]
end

class WorldObject
  attr_accessor :name, :description, :behaviors
    
  def name
    %{[[b;#aaf;#000]#{@name}]}
  end
    
  def WorldObject.find_or_create_the_shiny_book_of_help
    book = WorldObject.everything.select {|o| o.is_a?(Thing) && o.name == "The Shiny Book Of Help"}
    if book.size == 0
      help = Thing.new :name => "The Shiny Book Of Help", :description => "It's got it ALL! Add more!"
      WorldObject.everything << help
      help
    else 
      book.first
    end
  end

  def initialize
    raise "Wait! The name '#{self.name}' is already in use! Sorry. Try specifying another :name on creation." if WorldObject.everything.find {|o| o.name == self.name}
    WorldObject.everything << self
    @behaviors = {}
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
  
  def boot_the_scum
    orig = sleepers
    sleepers.each do |s|
      if s.is_bootable
        WorldObject.everything.delete s
        s.location.people.delete s
      end
    end
    orig - sleepers
  end
  
  def sweep
    orig = things
    things.each do |s|
      if s.is_sweepable
        WorldObject.everything.delete s
        s.location.items.delete s
      end
    end
    orig - things
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
  
  def help
    WorldObject.find_or_create_the_shiny_book_of_help
  end
  
  def display(object)
    "#{object.name}
    #{object.description}"
  end
  
  def everything
    WorldObject.everything
  end
  
  def welcome
    <<-EOF
  <pre>
  YOU HAVE ARRIVED. WELCOME.

  If it is your first time here, consider typing "help" and reading.
  </pre>
EOF
  end
  
  def local_ref(args)
    name, block = *args 
    found = []
    found += items.select {|i| i.name == name}
    found += @location.items.select {|i| i.name == name}
    found += @location.people.select {|i| i.name == name}
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

  def look(args=[])
    "#{@name}
    #{@description}
    Exits: #{@exits.keys}
    Occupants: #{@people}"
  end
  
end

class Person < WorldObject
  attr_accessor :items, :location, :is_bootable
  
  def save
    WorldObject.save(self)
  end
  
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
    CONNECTION_MAP[self].send divify(message, css_class) unless CONNECTION_MAP[self].nil?
  end

  def look(args=nil)
    name, block = *args 
    if args.nil?
      "#{@location.name}\n#{@location.description}\nExits: #{@location.exits.keys}\nOccupants: #{@location.people}"
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
      @location.look
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
    (@location.people - [self]).each{ |p| p.tx "#{self.name}: \"#{words}\"" }
    "#{self.name}: \"#{words}\""
  end
  alias :s :say
  
  def emote(args)
    action, block = *args 
    (@location.people - [self]).each{ |p| p.tx "#{self.name} #{action}" }
    "#{self.name} #{action}"
  end
  alias :e :emote
  
  def method_missing(m, *args, &block)
    return self.send(m, args, block) if self.respond_to? m
    return self.send(:use_exit, m.to_s) if @location.exits.keys.include? m.to_s
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

