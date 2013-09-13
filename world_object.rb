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
    #found += items.select {|i| i.name == name}
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
