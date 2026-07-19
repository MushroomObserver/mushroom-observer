# frozen_string_literal: true

# Sidebar indexes nav: names index filtered to those with
# observations.
class Tab::Sidebar::Indexes::Names < Tab::Base
  def title
    :names.ti
  end

  def path
    names_path(has_observations: true)
  end
end
