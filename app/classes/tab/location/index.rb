# frozen_string_literal: true

class Tab::Location::Index < Tab::Base
  def title
    :all_objects.t(type: :location)
  end

  def path
    locations_path
  end

  def model
    Location
  end
end
