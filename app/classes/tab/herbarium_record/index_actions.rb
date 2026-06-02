# frozen_string_literal: true

# Action-nav for the herbarium_records index page. When scoped to an
# observation, includes a back-to-observation link. Always includes
# the standard "create herbarium" + "nonpersonal herbaria index" tabs.
class Tab::HerbariumRecord::IndexActions < Tab::Collection
  def initialize(observation: nil, q_param: nil)
    super()
    @observation = observation
    @q_param = q_param
  end

  private

  def tabs
    [
      (Tab::Object::Return.new(object: @observation) if @observation),
      Tab::Herbarium::New.new,
      Tab::Herbarium::NonpersonalIndex.new(q_param: @q_param)
    ].compact
  end
end
