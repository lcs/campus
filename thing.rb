class Thing < WorldObject
  attr_accessor :name, :description, :is_sweepable

  def initialize(options={})
    @name = options[:name] || "A Thing"
    @description = options[:description] || "It feels like a thing."
    @is_sweepable = true
    super()
  end    

end

