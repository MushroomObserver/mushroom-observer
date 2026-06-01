# frozen_string_literal: true

class Tab::Location::Edit < Tab::Base
  def initialize(location:)
    super()
    @location = location
  end

  def title
    :show_location_edit.t
  end

  def path
    edit_location_path(@location.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @location
  end
end
