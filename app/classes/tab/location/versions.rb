# frozen_string_literal: true

# "Show location" link surfaced from the versions page. Pre-PORO
# title used `:show_location.t(location: ...)` with `alt_title:
# :show_object.t(TYPE: Location)`. Same shape preserved.
class Tab::Location::Versions < Tab::Base
  def initialize(location:)
    super()
    @location = location
  end

  def title
    :show_location.t(location: @location.display_name)
  end

  def path
    location_path(@location.id)
  end

  def alt_title
    :show_object.t(TYPE: Location)
  end

  def model
    @location
  end
end
