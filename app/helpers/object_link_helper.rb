#
#  = Object Link Helpers
#
#  These are helpers used to render links to various objects.
#
#  where_string::          Wrap location name in '<span>' tag.
#  location_link::         Wrap location name in link to show/search it.
#  name_link::             Wrap name in link to show_show.
#  user_link::             Wrap user name in link to show_user.
#  user_list::             Render list of users.
#  project_link::          Wrap project name in link to show_project.
#  description_title::     Create a meaningful title for a Description.
#  description_link::      Create a link to show a given Description.
#
################################################################################

module ApplicationHelper::ObjectLink

  # Wrap location name in span: "<span>where (count)</span>"
  #
  #   Where: <%= where_string(obs.place_name) %>
  #
  def where_string(where, count=nil)
    result = sanitize(where).t
    result += " (#{count})" if count
    result = "<span class=\"Data\">#{result}</span>"
  end

  # Wrap location name in link to show_location / observations_at_where.
  #
  #   Where: <%= location_link(obs.where, obs.location) %>
  #
  def location_link(where, location, count=nil, click=false)
    if location
      location = Location.find(location) if !location.is_a?(AbstractModel)
      link_string = where_string(location.display_name, count)
      link_string += " [#{:click_for_map.t}]" if click
      result = link_to(link_string, :controller => 'location', :action => 'show_location', :id => location.id)
    else
      link_string = where_string(where, count)
      link_string += " [#{:SEARCH.t}]" if click
      result = link_to(link_string, :controller => 'observer', :action => 'observations_at_where', :where => where)
    end
    result
  end

  # Wrap name in link to show_name.
  #
  #   Parent: <%= name_link(name.parent) %>
  #
  def name_link(name, str=nil)
    begin
      str ||= name.display_name.t
      name_id = name.is_a?(Fixnum) ? name : name.id
      link_to(str, :controller => 'name', :action => 'show_name', :id => name_id)
    rescue
    end
  end

  # Wrap user name in link to show_user.
  #
  #   Owner:   <%= user_link(name.user) %>
  #   Authors: <%= name.authors.map(&:user_link).join(', ') %>
  #
  #   # If you don't have a full User instance handy:
  #   Modified by: <%= user_link(login, user_id) %>
  #
  def user_link(user, name=nil)
    begin
      name ||= h(user.unique_text_name)
      user_id = user.is_a?(Fixnum) ? user : user.id
      link_to(name, :controller => 'observer', :action => 'show_user', :id => user_id)
    rescue
    end
  end

  # Render a list of users on one line.  (Renders nothing if user list empty.)
  # This renders the following strings:
  #
  #   <%= user_list('Author', name.authors) %>
  #
  #   empty:           ""
  #   [bob]:           "Author: Bob"
  #   [bob,fred,mary]: "Authors: Bob, Fred, Mary"
  #
  def user_list(title, users)
    result = ''
    count = users.length
    if count > 0
      result = (count > 1 ? title.to_s.pluralize.to_sym.t : title.t) + ": "
      result += users.map {|u| user_link(u, u.legal_name)}.join(', ')
    end
    result
  end

  # Wrap project name in link to show_project.
  #
  #   Project: <%= project_link(draft_name.project) %>
  def project_link(project, name=nil)
    begin
      name ||= sanitize(project.title).t
      link_to(name, :controller => 'project', :action => 'show_project', :id => project.id)
    rescue
    end
  end

  # Create a descriptive title for a Description.  Indicates the source and
  # very rough permissions (e.g. "public", "restricted", or "private").
  def description_title(desc)
    result = desc.partial_format_name.t

    # Indicate rough permissions.
    permit = if desc.parent.description_id == desc.id
      :default.l
    elsif desc.public
      :public.l
    elsif desc.is_reader?(@user)
      :restricted.l
    else
      :private.l
    end
    unless result.match(/(^| )#{permit}( |$)/i)
      result += " (#{permit})"
    end

    return result
  end

  # Wrap description title in link to show_description.
  #
  #   Description: <%= description_link(name.description) %>
  def description_link(desc)
    result = description_title(desc)
    if !result.match("(#{:private.t})$")
      result = link_to(result, :controller => desc.show_controller,
        :action => desc.show_action, :id => desc.id, :params => query_params)
    end
    return result
  end
end
