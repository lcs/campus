class Place < WorldObject

  attr_accessor :exits, :items, :people, :key, :creator

  def initialize(options = {})
    @name = options[:name] || "An Oobliette"
    @key = @name.titleize.gsub(/[^a-zA-Z0-9]/, "").underscore rescue "key_#{rand(99999999)}"
    @description = options[:description] || "A blank place. Dark and quiet. A perfect location to get an understanding on how this system works."
    @exits = {}
    @items = []
    @people = []
    @is_real = true
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
