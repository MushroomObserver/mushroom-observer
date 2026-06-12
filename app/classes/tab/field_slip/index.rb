# frozen_string_literal: true

# "Field slips index" link.
class Tab::FieldSlip::Index < Tab::Base
  def title
    :INDEX_OBJECT.t(type: :field_slips)
  end

  def path
    field_slips_path
  end

  def model
    FieldSlip
  end
end
