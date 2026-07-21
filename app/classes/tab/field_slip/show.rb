# frozen_string_literal: true

# "Show field slip" link.
class Tab::FieldSlip::Show < Tab::Base
  def initialize(field_slip:)
    super()
    @field_slip = field_slip
  end

  def title
    :show_object.t(type: :field_slip)
  end

  def path
    field_slip_path(@field_slip)
  end

  def model
    @field_slip
  end
end
