# frozen_string_literal: true

# "Show the location's primary description" link — caller must
# guard on `location&.description` before constructing (Tab POROs
# don't return nil from their constructor).
class Tab::Location::ShowDescription < Tab::Base
  def initialize(location:)
    super()
    @location = location
  end

  def title
    :show_name_see_more.l
  end

  def path
    location_description_path(@location.description.id)
  end

  def html_options
    { icon: :list }
  end

  def model
    @location
  end
end
