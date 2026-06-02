# frozen_string_literal: true

# Action-nav for the field_slips index page.
class Tab::FieldSlip::IndexActions < Tab::Collection
  private

  def tabs
    [Tab::FieldSlip::New.new]
  end
end
