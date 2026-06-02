# frozen_string_literal: true

# "New field slip" link.
class Tab::FieldSlip::New < Tab::Base
  def title
    :field_slip_new.t
  end

  def path
    new_field_slip_path
  end

  def model
    FieldSlip
  end
end
