# frozen_string_literal: true

class Tab::Location::Undefined < Tab::Base
  def title
    :list_place_names_undef.t
  end

  def path
    undefined_locations_path
  end
end
