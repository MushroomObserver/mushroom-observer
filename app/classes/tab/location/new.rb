# frozen_string_literal: true

class Tab::Location::New < Tab::Base
  def title
    :show_location_create.t
  end

  def path
    new_location_path
  end

  def html_options
    { icon: :add }
  end

  def model
    Location
  end
end
