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
