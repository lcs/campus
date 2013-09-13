class Thing < WorldObject
  attr_accessor :name, :description, :held_by, :creator

  def initialize(options={})
    @name = options[:name] || "A Primordeal Thing"
    @held_by = options[:creator]
    @creator = options[:creator]
    @description = options[:description] || "It feels like a smooshy thing...unformed...ready to be molded into somthing else."
    super()
  end    

end

