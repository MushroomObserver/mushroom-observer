# frozen_string_literal: true

# Sidebar indexes nav: locations index.
class Tab::Sidebar::Indexes::Locations < Tab::Base
  def title
    :locations.ti
  end

  def path
    locations_path
  end
end
