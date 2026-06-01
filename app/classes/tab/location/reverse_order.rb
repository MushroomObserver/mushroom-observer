# frozen_string_literal: true

class Tab::Location::ReverseOrder < Tab::Base
  def initialize(location:)
    super()
    @location = location
  end

  def title
    :show_location_reverse.t
  end

  def path
    reverse_name_order_location_path(@location.id)
  end

  def html_options
    { icon: :back }
  end

  def model
    @location
  end
end
