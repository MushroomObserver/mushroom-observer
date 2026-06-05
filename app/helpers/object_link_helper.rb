# frozen_string_literal: true

# helpers for creating links in views
module ObjectLinkHelper
  # Wrap location name in link to show_location OR observations/index.
  #
  # NEW 2024-02-01 AN: Only accepts a postal format string for `where`, e.g.
  #   Location.name, Observation.where, SpeciesList.where, User.location.name
  #
  # This method prints both postal and scientific formats, shown/hidden with
  # CSS, using a governing class on the <body> that has the user's preference
  #
  #   Where: <%= location_link(obs.where, obs.location) %>
  #
  # Kept for ERB callers. Phlex callers should
  # `render(Components::LocationLink.new(...))` directly instead.
  def location_link(where, location, count = nil, click = false)
    render(Components::LocationLink.new(
             where: where, location: location,
             count: count, click: click
           ))
  end

  # Wrap both formats of location.name in spans,
  #   maybe adding a count, and wrap the whole thing in a span too:
  #   <span><span class="location-postal">where</span> \
  #         <span class="location-scientific">where</span> (count)</span>
  #
  #   Where: <%= where_string(obs.where) %>
  #
  def where_string(where, count = nil)
    postal = tag.span(where, class: "location-postal")
    scientific = tag.span(Location.reverse_name(where),
                          class: "location-scientific")

    add_count = count ? " (#{count})" : ""
    tag.span { [postal, scientific, add_count].safe_join }
  end

  # Wrap name in link to show_name. Takes id or object
  #
  #   Parent: <%= name_link(name.parent) %>
  #
  def name_link(name, str = nil)
    if name.is_a?(Integer)
      str ||= "#{:NAME.t} ##{name}"
      id = name
    else
      str ||= name.display_name_brief_authors.t
      id = name.id
    end
    link_to(str, name_path(id), { class: "name_link_#{id}" })
  end

  # Wrap user name in link to show_user.
  #
  #   Owner:   <%= user_link(name.user) %>
  #   Authors: <%= name.authors.map(&:user_link).join(", ") %>
  #
  #   # If you don't have a full User instance handy:
  #   Modified by: <%= user_link(login, user_id) %>
  #
  # Kept for ERB callers and a handful of Phlex spots that build
  # SafeBuffer strings via `safe_join` (where rendering a component
  # mid-string-build is awkward). Phlex callers in regular template
  # context should `render(Components::UserLink.new(...))` directly.
  def user_link(user, name = nil, args = {})
    render(Components::UserLink.new(user: user, name: name,
                                    attributes: args))
  end

  # Wrap object's name in link to the object, return nil if no object
  #   Project: <%= project_link(draft_name.project) %>
  #   Species List: <%= species_list_link(observation.species_lists.first) %>
  # Kept for the two remaining ERB callers
  # (`images/show/_info_panel.html.erb`, `field_slips/_field_slip.html.erb`).
  # Phlex callers should `render(Components::ObjectLink.new(...))`
  # directly instead.
  def link_to_object(object, name = nil)
    return nil unless object

    render(Components::ObjectLink.new(object: object, name: name))
  end

  def observation_herbarium_record_link(obs)
    count = obs.herbarium_records.size
    if count.positive?

      link_to((count == 1 ? :herbarium_record.t : :herbarium_records.t),
              herbarium_records_path(observation: obs.id),
              { class: "herbarium_records_for_observation_link" })
    else
      return :show_observation_specimen_available.t if obs.specimen

      :show_observation_specimen_not_available.t
    end
  end
end
