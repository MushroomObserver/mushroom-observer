# frozen_string_literal: true

# Action-nav for the field_slip edit form.
class Tab::FieldSlip::FormEdit < Tab::Collection
  def initialize(field_slip:)
    super()
    @field_slip = field_slip
  end

  private

  def tabs
    [Tab::FieldSlip::Index.new,
     Tab::FieldSlip::Show.new(field_slip: @field_slip)]
  end
end
