# frozen_string_literal: true

# Distribution-map link for a name. Intentionally does NOT thread a
# q_param through — issue #4139 surfaced that an inherited
# `in_box` filter from a prior map popup's Show-All / Map-All click
# would silently restrict this map to that bbox. The link always
# lands on the full distribution map.
class Tab::Name::OccurrenceMap < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_name_distribution_map.t
  end

  def path
    map_name_path(id: @name.id)
  end

  def html_options
    { data: { action: "links#disable" } }
  end

  def model
    @name
  end
end
