# frozen_string_literal: true

# Action-nav for the herbarium_record edit form. The back link
# depends on where the user came from: `back == "index"` → return to
# the herbarium_records index; otherwise → return to `back_object`
# (typically the parent Observation).
class Tab::HerbariumRecord::FormEdit < Tab::Collection
  def initialize(back:, back_object:, q_param: nil)
    super()
    @back = back
    @back_object = back_object
    @q_param = q_param
  end

  private

  def tabs
    [
      back_link,
      Tab::Herbarium::New.new,
      Tab::Herbarium::NonpersonalIndex.new(q_param: @q_param)
    ].compact
  end

  def back_link
    return Tab::HerbariumRecord::BackToIndex.new(q_param: @q_param) \
      if @back == "index"
    return Tab::Object::Return.new(object: @back_object) if @back_object

    nil
  end
end
