# frozen_string_literal: true

# Sidebar indexes nav: names index filtered to those with
# observations.
class Tab::Sidebar::Indexes::Names < Tab::Base
  def title
    :NAMES.t
  end

  def path
    names_path(has_observations: true)
  end

  def html_options
    { id: "nav_name_observations_link" }
  end
end
