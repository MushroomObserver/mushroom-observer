# frozen_string_literal: true

# Sidebar indexes nav: locations index.
class Tab::Sidebar::Indexes::Locations < Tab::Base
  def title
    :LOCATIONS.t
  end

  def path
    locations_path
  end
end
