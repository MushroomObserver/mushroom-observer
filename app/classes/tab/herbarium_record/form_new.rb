# frozen_string_literal: true

# Action-nav for the herbarium_record new form.
class Tab::HerbariumRecord::FormNew < Tab::Collection
  def initialize(observation:, q_param: nil)
    super()
    @observation = observation
    @q_param = q_param
  end

  private

  def tabs
    [
      Tab::Object::Return.new(object: @observation),
      Tab::Herbarium::New.new,
      Tab::Herbarium::NonpersonalIndex.new(q_param: @q_param)
    ]
  end
end
