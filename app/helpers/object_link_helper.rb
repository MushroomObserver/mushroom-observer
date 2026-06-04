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
  def location_link(where, location, count = nil, click = false)
    if location
      location = Location.find(location) unless location.is_a?(AbstractModel)
      link_string = where_string(location.name, count)
      link_string += " [#{:click_for_map.t}]" if click
      link_to(link_string, location_path(id: location.id),
              { class: "show_location_link show_location_link_#{location.id}" })
    else
      link_string = where_string(where, count)
      link_string += " [#{:SEARCH.t}]" if click
      link_to(link_string, observations_path(where: where),
              { class: "index_observations_at_where_link" })
    end
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
  def user_link(user, name = nil, args = {})
    if !user
      return :unknown_user_name.t
    elsif user.is_a?(Integer)
      name ||= "#{:USER.t} ##{user}"
      user_id = user
    elsif user
      name ||= user.unique_text_name
      user_id = user.id
    end

    link_to(
      name, user_path(user_id),
      args.merge(
        { class: class_names("user_link_#{user_id}", args[:class]) }
      )
    )
  end

  # Wrap object's name in link to the object, return nil if no object
  #   Project: <%= project_link(draft_name.project) %>
  #   Species List: <%= species_list_link(observation.species_lists.first) %>
  def link_to_object(object, name = nil)
    return nil unless object

    unique_class = "#{object.type_tag}_link_#{object.id}"
    link_to(name || object.title.t, object.show_link_args,
            { class: unique_class })
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
