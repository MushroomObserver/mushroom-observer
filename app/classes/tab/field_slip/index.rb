# frozen_string_literal: true

# "Field slips index" link.
class Tab::FieldSlip::Index < Tab::Base
  def title
    :index_object.ti(type: :field_slips)
  end

  def path
    field_slips_path
  end

  def model
    FieldSlip
  end
end
