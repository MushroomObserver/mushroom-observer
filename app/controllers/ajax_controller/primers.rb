# frozen_string_literal: true

# see ajax_controller.rb
class AjaxController
  # Get list of names for autocompletion in mobile app.
  def name_primer
    render(json: name_list)
  end

  # Get list of locations for autocompletion in mobile app.
  def location_primer
    render(json: location_list)
  end

  private

  def name_list
    [ [1, "alpha"], [2, "beta"], [3, "charley"], [4, "delta"] ]
  end

  def location_list
    nil
  end
end
