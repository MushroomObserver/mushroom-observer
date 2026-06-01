# frozen_string_literal: true

class Tab::Location::Countries < Tab::Base
  def title
    :list_countries.t
  end

  def path
    location_countries_path
  end
end
