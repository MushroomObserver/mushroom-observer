# frozen_string_literal: true

class Tab::Name::FormEdit < Tab::Collection
  def initialize(name:, index_filter: nil)
    super()
    @name = name
    @index_filter = index_filter
  end

  private

  def tabs
    [
      Tab::Object::Return.new(object: @name),
      Tab::Object::Index.new(object: @name, index_filter: @index_filter)
    ]
  end
end
