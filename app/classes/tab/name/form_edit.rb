# frozen_string_literal: true

class Tab::Name::FormEdit < Tab::Collection
  def initialize(name:, q_param: nil)
    super()
    @name = name
    @q_param = q_param
  end

  private

  def tabs
    [
      Tab::Object::Return.new(object: @name),
      Tab::Object::Index.new(object: @name, q_param: @q_param)
    ]
  end
end
