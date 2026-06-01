# frozen_string_literal: true

class Tab::Location::NewDescription < Tab::Base
  def initialize(location:)
    super()
    @location = location
  end

  def title
    :show_name_create_description.l
  end

  def path
    new_location_description_path(@location.id)
  end

  def html_options
    { icon: :add }
  end

  def model
    @location
  end
end
