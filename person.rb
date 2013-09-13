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
