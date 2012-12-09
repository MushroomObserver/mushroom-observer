# encoding: utf-8
#
#  = Object Link Helpers
#
#  These are helpers used to render links to various objects.
#
#  where_string::         Wrap location name in '<span>' tag.
#  location_link::        Wrap location name in link to show/search it.
#  name_link::            Wrap name in link to show_show.
#  user_link::            Wrap user name in link to show_user.
#  user_list::            Render list of users.
#  project_link::         Wrap project name in link to show_project.
#  species_list_link::    Wrap species_list name in link to show_species_list.
#  description_title::    Create a meaningful title for a Description.
#  description_link::     Create a link to show a given Description.
#  thumbnail::            Draw thumbnail image linked to show_image.
#  image_vote_tabs::      Render the AJAX vote tabs that go below thumbnails.
#  set_export_status_controls:: Render the two set_export_status controls.
#
################################################################################

module ApplicationHelper::ObjectLink

  # Wrap location name in span: "<span>where (count)</span>"
  #
  #   Where: <%= where_string(obs.place_name) %>
  #
  def where_string(where, count=nil)
    result = where.t
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
    str ||= name.display_name.t
    name_id = name.is_a?(Fixnum) ? name : name.id
    link_to(str, :controller => 'name', :action => 'show_name', :id => name_id)
  rescue
  end

  # Create link for name to MyCoPortal website.
  def mycoportal_url(name)
    'http://mycoportal.org/portal/taxa/index.php?taxauthid=1&taxon=' +
      name.text_name.gsub(' ','+')
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
      (user || name).to_s
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
    if project
      name ||= project.title.t
      link_to(name, :controller => 'project', :action => 'show_project', :id => project.id)
    end
  end

  # Wrap species_list name in link to show_species_list.
  #
  #   Species List: <%= species_list_link(observation.species_lists.first) %>
  def species_list_link(species_list, name=nil)
    if species_list
      name ||= species_list.title.t
      link_to(name, :controller => 'species_list', :action => 'show_species_list',
              :id => species_list.id)
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

  # Draw a thumbnail image.  It takes either an Image instance or an id.  Args:
  # size::      Size of image.  (default is user's default thumbnail size)
  # link::      :show_image, :show_observation, :show_user, :none, or Hash of +link_to+ args.  (default is :show_image)
  # obs::       Add <tt>:obs => id</tt> to the show_image link args.
  # user::      (used with :link => :show_user)
  # border::    Set +border+ attribute, e.g. <tt>:border => 0</tt>.
  # style::     Add +style+ attribute, e.g. <tt>:style => 'float:right'</tt>.
  # class::     Set +class+ attribute, e.g. <tt>:class => 'thumbnail'</tt>.
  # append::    HTML to tack on after +img+ tag; will be included in the link.
  # votes::     Add AJAX vote links below image?
  # nodiv::     Tell it not to wrap it in a div.
  # target::    Add target to anchor-link.
  def thumbnail(image, args={})
    if image.is_a?(Image)
      id = image.id
    else
      id = image.to_s.to_i
      image = nil
    end

    # Get URL to image.
    size = (args[:size] || default_thumbnail_size).to_sym
    if size == :original
      # Must pass in image instance to display original!
      file = image.original_file
    else
      file = Image.file_name(size, id)
    end
    if image && !image.transferred && size != :thumbnail
      # Serve image from web server if it hasn't transferred yet.  Since apache can't know
      # about this, we have to fake it into thinking it's not serving an image.  Route it
      # through ajax controller to reduce overhead to minimum.
      file = "/ajax/image/#{file.sub(/\.jpg$/,'')}"
    elsif DEVELOPMENT and !File.exists?("#{IMG_DIR}/#{file}")
      # Serve images I'm locally missing directly from image server.
      file = Image.url(size, id)
    end

    # Create <img> tag.
    opts = {}
    opts[:border] = args[:border] if args.has_key?(:border)
    opts[:style]  = args[:style]  if args.has_key?(:style)
    str = image_tag(file, opts)
    str += args[:append].to_s

    # Decide what to link it to.
    case link = args[:link] || :show_image
    when :show_image
      link = { :controller => 'image', :action => 'show_image', :id => id,
               :params => args[:query_params] || query_params }
      link[:obs] = args[:obs] if args.has_key?(:obs)
    when :show_observation
      link = { :controller => 'observer', :action => 'show_observation',
               :id => args[:obs], :params => args[:query_params] || query_params }
      raise "missing :obs" if !args.has_key?(:obs)
    when :show_user
      link = { :controller => 'observer', :action => 'show_user',
               :id => args[:user] }
      raise "missing :user" if !args.has_key?(:user)
    when :none
      link = nil
    when Hash
    else
      raise "invalid link"
    end

    # Enclose image in a link?
    link_args = {}
    link_args[:target] = args[:target] if args[:target]
    result = link ? link_to(str, link, link_args) : str

    # Include AJAX vote links below image?
    if @js && @user && args[:votes]
      table = image_vote_tabs(image || id, args[:vote_data])
      result += '<br/>' + content_tag(:div, table, :id => "image_votes_#{id}")
      did_vote_div = true
    end

    # Include original filename.
    if args[:original] and
       image and !image.original_name.blank? and
       check_permission(image)
      result += '<br/>' unless did_vote_div
      result += h(image.original_name)
    end

    # Wrap result in div.
    if args[:nodiv]
      result
    else
      content_tag(:div, result, :class => args[:class] || 'thumbnail')
    end
  end

  # Provide the copyright for an image
  def image_copyright(image)
    year = image.when
    year = image.when.year if year
    link = if image.copyright_holder == image.user.legal_name
      link = user_link(image.user)
    else
      link = image.copyright_holder.to_s.t
    end
    "<div id=\"copyright\"> #{:image_show_copyright.t} &copy;#{year} #{link} </div>"
  end

  def export_link(image_id, exported)
    if exported
      link_to_function('Not for Export', "image_export(#{image_id},0)")
    else
      link_to_function('For Export', "image_export(#{image_id},1)")
    end
  end
  
  def image_exporter(image_id, exported)
    javascript_include('prototype')
    javascript_include('image_export')

    content_tag(:div, export_link(image_id, exported), :id => "image_export_#{image_id}")
  end
  
  # Render the AJAX vote tabs that go below thumbnails.
  def image_vote_tabs(image, data=nil)
    javascript_include('prototype')
    javascript_include('image_vote')

    if image.is_a?(Image)
      id  = image.id
      cur = image.users_vote(@user)
      avg = image.vote_cache
      num = image.num_votes
    else
      id  = image.to_i
      cur = nil
      avg = nil
      num = nil
    end

    row1 = ''
    if avg and num and num > 0
      num += 1
      num = 8 if num > 8
      row1 += content_tag(:td, '', :height => num) if cur.to_i > 0
      Image.all_votes.map do |val|
        if val <= avg
          str = content_tag(:div, '', :class => 'on')
        elsif val <= avg + 1.0
          pct = ((avg + 1.0 - val) * 100).to_i
          str = content_tag(:div, '', :class => 'on',
                              :style => "width:#{pct}%")
        else
          str = ''
        end
        row1 += content_tag(:td, str, :height => num)
      end
      row1 = content_tag(:tr, row1)
    end

    row2 = ''
    str = link_to_function('(X)', "image_vote(#{id},0)",
                           :title => :image_vote_help_0.l)
    str += indent(5)
    row2 += content_tag(:td, content_tag(:small, str)) if cur.to_i > 0
    Image.all_votes.map do |val|
      str1 = image_vote_as_short_string(val)
      str2 = image_vote_as_help_string(val)
      if val == cur
        str = content_tag(:b, content_tag(:span, str1, :title => str2))
      else
        str = link_to_function(str1, "image_vote(#{id},'#{val}')",
                               :title => str2)
      end
      str = '&nbsp;|&nbsp;' + str if val > 1
      row2 += content_tag(:td, content_tag(:small, str))
    end
    row2 = content_tag(:tr, row2)

    content_tag(:table, row1 + row2, :class => 'vote_meter',
                :cellspacing => '0', :cellpadding => '0')
  end

  # Display the two export statuses, making the current state plain text and
  # the other a link to the observer/set_export_status callback.
  def set_export_status_controls(obj)
    if is_reviewer?
      if obj.ok_for_export
        content_tag(:b, :review_ok_for_export.t)
      else
        link_to(:review_ok_for_export.t, :controller => 'observer',
                :action => 'set_export_status', :type => obj.type_tag,
                :id => obj.id, :value => '1', :params => query_params)
      end + '<br/>' +
      if obj.ok_for_export
        link_to(:review_no_export.t, :controller => 'observer',
                :action => 'set_export_status', :type => obj.type_tag,
                :id => obj.id, :value => '0', :params => query_params)
      else
        content_tag(:b, :review_no_export.t)
      end
    end
  end
  
  def observation_specimen_info(obs)
    "<span class=\"Data\">#{observation_specimen_link(obs)}</span> #{create_specimen_link(obs)}"
  end
    
  def observation_specimen_link(obs)
    count = obs.specimens.count
    if obs.specimens.count > 0
      link_to(:show_observation_specimens.t,
              :controller => 'specimen', :action => 'observation_index', :id => obs.id)
    else
      if obs.specimen
        :show_observation_specimen_available.t
      else
        :show_observation_specimen_not_available.t
      end
    end
  end
  
  def create_specimen_link(obs)
    if check_permission(obs) or (@user && (@user.curated_herbaria.length > 0))
		  " | " + link_to(:show_observation_create_specimen.t,
						          :controller => 'specimen', :action => 'add_specimen',
						          :id => obs.id, :params => query_params)
		else
		  ""
		end
	end
	
end
