class MinimalMapLocation
  attr_accessor :id, :name, :north, :south, :east, :west

  def initialize(id, name, north, south, east, west)
    @id    = id
    @name  = name
    @north = north
    @south = south
    @east  = east
    @west  = west
  end

  include BoxMethods

  def display_name
    User.current_location_format == :scientific ? Location.reverse_name(name) : name
  end
end
