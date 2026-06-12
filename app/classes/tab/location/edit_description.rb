# frozen_string_literal: true

class Tab::Location::EditDescription < Tab::Base
  def initialize(location:)
    super()
    @location = location
  end

  def title
    :EDIT.l
  end

  def path
    edit_location_description_path(@location.description.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @location
  end
end
