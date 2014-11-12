# encoding: utf-8
#
#  = Application Helpers
#
#  These methods are available to all templates in the application:
#
#  ==== Localization
#  rank_as_string::         Translate :Genus into "Genus" (localized).
#  rank_as_lower_string::   Translate :Genus into "genus" (localized).
#  rank_as_plural_string::  Translate :Genus into "Genera" (localized).
#  image_vote_as_long_string::  Translate image vote into (long) localized String with short version enboldened.
#  image_vote_as_help_string::  Translate image vote into (long) localized String.
#  image_vote_as_short_string:: Translate image vote into (short) localized String.
#  review_as_string::       Translate review status into localized String.
#
#  ==== Other Stuff
#  show_object_footer::     Show the created_at/updated_at/view dates and RSS log.
#
################################################################################

# From map_helper.rb
require_dependency 'map_collapsible'
require_dependency 'map_set'
require_dependency 'gmaps'

module ApplicationHelper

  # For now, just use Browser gem's "modern?" criteria.  Used to be:
  #   Firefox/Iceweasel > 1.0
  #   Netscape > 7.0
  #   Safari > 1.2
  #   IE > 5.5
  #   Opera (all)
  #   Chrome (all)
  def can_do_ajax?
    browser.modern? || TESTING
  end

  ##############################################################################
  #
  #  :section: Localization
  #
  ##############################################################################

  # Translate Name rank (singular).
  #
  #   rank_as_string(:genus)  -->  "Genus"
  #
  def rank_as_string(rank)
    :"RANK_#{rank.to_s.upcase}".l
  end

  # Translate Name rank (singular).
  #
  #   rank_as_lower_string(:genus)  -->  "genus"
  #
  def rank_as_lower_string(rank)
    :"rank_#{rank.to_s.downcase}".l
  end

  # Translate Name rank (plural).
  #
  #   rank_as_plural_string(:genus)  -->  "Genera"
  #
  def rank_as_plural_string(rank)
    :"RANK_PLURAL_#{rank.to_s.upcase}".l
  end

  # Translate Name rank (plural).
  #
  #   rank_as_plural_string(:genus)  -->  "genera"
  #
  def rank_as_lower_plural_string(rank)
    :"rank_plural_#{rank.to_s.downcase}".l
  end

  # Translate image quality.
  #
  #   image_vote_as_long_string(3)  -->  "**Good** enough for a field guide."
  #
  def image_vote_as_long_string(val)
    :"image_vote_long_#{val || 0}".l
  end

  # Translate image quality.
  #
  #   image_vote_as_help_string(3)  -->  "Good enough for a field guide."
  #
  def image_vote_as_help_string(val)
    :"image_vote_help_#{val || 0}".l
  end

  # Translate image quality.
  #
  #   image_vote_as_short_string(3)  -->  "Good"
  #
  def image_vote_as_short_string(val)
    :"image_vote_short_#{val || 0}".l
  end

  # Translate review status.
  #
  #   review_as_string(:unvetted)  -->  "Reviewed"
  #
  def review_as_string(val)
    :"review_#{val}".l
  end

  def safe_empty; "".html_safe; end
  def safe_br; "<br/>".html_safe; end
  def safe_nbsp; "&nbsp;".html_safe; end

  def link_with_query(name = nil, options = nil, html_options = nil)
    link_to(name, add_query_param(options), html_options)
  end

  # Rails 3.x has broken the link_to :confirm mechanism.  The new method requires
  # rather sophisticated javascript capabilities (in rails.js).  I'd far prefer
  # to keep the old blindingly simple onclick="return confirm()" mechanism.
  def link_to(*args)
    super(*args).sub(/data-confirm="(.*?)"/,
      'onclick="' + CGI.escapeHTML('return confirm("\1")') + '"').html_safe
  end

  ##############################################################################
  #
  #  :section: Other Stuff
  #
  ##############################################################################

  # Renders the little footer at the bottom of show_object pages.
  #
  #   <%= show_object_footer(@name) %>
  #
  #   # Non-versioned object:
  #   <p>
  #     <span class="Date">
  #       Created: <date><br/>
  #       Last Modified: <date><br/>
  #       Viewed: <num> times, last viewed: <date><br/>
  #       Show Log<br/>
  #     </span>
  #   </p>
  #
  #   # Latest version of versioned object:
  #   <p>
  #     <span class="Date">
  #       Created: <date> by <user><br/>
  #       Last Modified: <date> by <user><br/>
  #       Viewed: <num> times, last viewed: <date><br/>
  #       Show Log<br/>
  #     </span>
  #   </p>
  #
  #   # Old version of versioned object:
  #   <p>
  #     <span class="Date">
  #       Version: <num> of <total>
  #       Modified: <date> by <user><br/>
  #       Show Log<br/>
  #     </span>
  #   </p>
  #
  def show_object_footer(obj)
    html = []
    type = obj.type_tag
    num_versions = obj.respond_to?(:version) ? obj.versions.length : 0

    # Old version of versioned object.
    if num_versions > 0 && obj.version < num_versions
      html << :footer_version_out_of.t(:num => obj.version,
                                    :total => num_versions)
      html << :footer_updated_by.t(:user => user_link(obj.user),
                                 :date => obj.updated_at.web_time) if obj.updated_at

    # Latest version or non-versioned object.
    else
      if num_versions > 0
        latest_user = User.safe_find(obj.versions.latest.user_id)
        html << :footer_created_by.t(:user => user_link(obj.user),
                                  :date => obj.created_at.web_time) if obj.created_at
        if latest_user && obj.updated_at
          html << :footer_last_updated_by.t(:user => user_link(latest_user),
                                             :date => obj.updated_at.web_time)
        elsif obj.updated_at
          html << :footer_last_updated_at.t(:date => obj.updated_at.web_time)
        end
      else
        html << :footer_created_at.t(:date => obj.created_at.web_time) if obj.created_at
        html << :footer_last_updated_at.t(:date => obj.updated_at.web_time) if obj.updated_at
      end
      if obj.respond_to?(:num_views)
        html << :footer_viewed.t(:date => obj.last_view.web_time,
                                :times => obj.num_views == 1 ? :one_time.l :
                                :many_times.l(:num => obj.num_views)) if obj.last_view
      end
    end

    # Show RSS log for all of the above.
    if obj.respond_to?(:rss_log_id) and obj.rss_log_id
      html << link_to(:show_object.t(:type => :log),
                      :controller => 'observer', :action => 'show_rss_log',
                      :id => obj.rss_log_id)
    end

    html = html.safe_join(safe_br)
    html = content_tag(:p, html, class: "Date")
  end

  def herbarium_name_box(default_name="")
    content_tag(:label, :specimen_herbarium_name.t, :for => :specimen_herbarium_name) + ': ' +
    text_field(:specimen, :herbarium_name, :value => @herbarium_name, :size => 60) +
    turn_into_herbarium_auto_completer(:specimen_herbarium_name)
  end

  def herbarium_id_box
    content_tag(:label, :specimen_herbarium_id.t, :for => :specimen_herbarium_id) + ': ' +
    text_field(:specimen, :herbarium_id, :value => @herbarium_id, :size => 20)
  end

  def table_column_title(title)
    content_tag(:td, title, :align => :center, :class => :TableColumn)
  end

  ### From auto_complete_helper.rb

  # Add another input field onto an existing auto-completer.
  def reuse_auto_completer(first_id, new_id)
    javascript_tag("AUTOCOMPLETERS['#{first_id}'].reuse('#{new_id}')")
  end

  # Turn a text_field into an auto-completer.
  # id::   id of text_field
  # opts:: arguments (see autocomplete.js)
  def turn_into_auto_completer(id, opts={})
    if can_do_ajax?
      javascript_include 'jquery'
      javascript_include 'jquery_extensions'
      javascript_include 'autocomplete'
      js_args = []
      opts[:input_id]   = id
      opts[:row_height] = 22
      opts.each_pair do |key, val|
        if key.to_s == 'primer'
          list = val ? val.reject(&:blank?).map(&:to_s).uniq.join("\n") : ''
          js_args << "primer: '" + escape_javascript(list) + "'"
        else
          if !key.to_s.match(/^on/) &&
             !val.to_s.match(/^(-?\d+(\.\d+)?|true|false|null)$/)
            val = "'" + escape_javascript(val.to_s) + "'"
          end
          js_args << "#{key}: #{val}"
        end
      end
      js_args = js_args.join(', ')

      result = javascript_tag("new MOAutocompleter({ #{js_args} })")
    else
      result = ''
    end
    return result
  end

  # Make text_field auto-complete for fixed set of strings.
  def turn_into_menu_auto_completer(id, opts={})
    raise "Missing primer for menu auto-completer!" if !opts[:primer]
    turn_into_auto_completer(id, {
      :unordered => false
    }.merge(opts))
  end

  # Make text_field auto-complete for Name text_name.
  def turn_into_name_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/name/@',
      :collapse => 1
    }.merge(opts))
  end

  # Make text_field auto-complete for Location display name.
  def turn_into_location_auto_completer(id, opts={})
    if @user and @user.location_format == :scientific
      format = '?format=scientific'
    else
      format = ''
    end
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/location/@' + format,
      :unordered => true
    }.merge(opts))
  end

  # Make text_field auto-complete for Project title.
  def turn_into_project_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/project/@',
      :unordered => true
    }.merge(opts))
  end

  # Make text_field auto-complete for SpeciesList title.
  def turn_into_species_list_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/species_list/@',
      :unordered => true
    }.merge(opts))
  end

  # Make text_field auto-complete for User name/login.
  def turn_into_user_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/user/@',
      :unordered => true
    }.merge(opts))
  end

  # Make text_field auto-complete for Herbarium name.
  def turn_into_herbarium_auto_completer(id, opts={})
    if @user
      turn_into_auto_completer(id, {
        :ajax_url => '/ajax/auto_complete/herbarium/@?user_id=' + @user.id.to_s,
        :unordered => true
      }.merge(opts))
    else
      ''
    end
  end

  # From description_helper.rb
  # Create tabs for show_description page.
  def show_description_tab_set(desc)
    type = desc.type_tag.to_s.sub(/_description/, '').to_sym
    writer = desc.is_writer?(@user) || is_in_admin_mode?
    admin  = desc.is_admin?(@user)  || is_in_admin_mode?
    new_tab_set do
      if true
        add_tab_with_query(:show_object.t(:type => type),
          :action => "show_#{type}", :id => desc.parent_id)
      end
      if (desc.source_type == :project) and
         (project = desc.source_object)
        add_tab_with_query(:show_object.t(:type => :project),
          :controller => 'project', :action => 'show_project',
          :id => project.id)
      end
      if admin
        add_tab_with_query(:show_description_destroy.t,
          { :action => "destroy_#{type}_description", :id => desc.id },
          { :confirm => :are_you_sure.l })
      end
      if true
        add_tab_with_query(:show_description_clone.t,
          :controller => type,
          :action => "create_#{type}_description", :id => desc.parent_id,
          :clone => desc.id, :help => :show_description_clone_help.l)
      end
      if admin
        add_tab_with_query(:show_description_merge.t,
          :action => 'merge_descriptions', :id => desc.id,
          :help => :show_description_merge_help.l)
      end
      if admin
        add_tab_with_query(:show_description_adjust_permissions.t,
          :action => 'adjust_permissions', :id => @description.id,
          :help => :show_description_adjust_permissions_help.l)
      end
      if desc.public && @user && (desc.parent.description_id != desc.id)
        add_tab_with_query(:show_description_make_default.t,
          :action => 'make_description_default', :id => desc.id,
          :help => :show_description_make_default_help.l)
      end
      if admin and (desc.source_type != :public)
        add_tab_with_query(:show_description_publish.t,
          :action => 'publish_description', :id => desc.id,
          :help => :show_description_publish_help.l)
      end
      if writer
        add_tab_with_query(:show_description_edit.t,
          :action => "edit_#{type}_description", :id => desc.id)
      end
    end

    draw_prev_next_tabs(desc)
  end

  # Header of the embedded description within a show_object page.
  #
  #   <%= show_embedded_description_title(desc, name) %>
  #
  #   # Renders something like this:
  #   <p>EOL Project Draft: Show | Edit | Destroy</p>
  #
  def show_embedded_description_title(desc, parent)
    type = desc.type_tag
    title = description_title(desc)
    links = []
    if @user && desc.is_writer?(@user)
      links << link_with_query(:EDIT.t, :id => desc.id,
        :action => "edit_#{type}")
    end
    if @user && desc.is_admin?(@user)
      links << link_with_query(:DESTROY.t, :id => desc.id,
        :action => "destroy_#{type}")
    end
    content_tag(:p, content_tag(:big, title) + links.safe_join(' | '))
  end

  def show_best_image(obs)
    result = ""
    if obs
      if image = obs.thumb_image
        result = thumbnail(image, :border => 0, :link => :show_observation,
                           :obs => obs.id, :size => :small) + image_copyright(image)
      end
    end
    result
  end

  def list_descriptions(obj, fake_default=false)
    type = obj.type_tag

    # Filter out empty descriptions (unless it's public or one you own).
    list = obj.descriptions.select do |desc|
      desc.has_any_notes?  or
      (desc.user == @user) or
      is_reviewer          or
      (desc.source_type == :public)
    end

    # Sort, putting the default one on top, followed by public ones, followed
    # by others ending in personal ones, sorting by "length" among groups.
    type_order = Description.all_source_types
    list.sort! do |a,b|
      x = (obj.description_id == a.id ? 0 : 1) <=>
          (obj.description_id == b.id ? 0 : 1)
      x = type_order.index(a.source_type) <=>
          type_order.index(b.source_type) if x == 0
      if x == 0
        as = a.note_status
        bs = b.note_status
        x = bs[0] <=> as[0] if x == 0
        x = bs[1] <=> as[1] if x == 0
      end
      x = description_title(a) <=> description_title(b) if x == 0
      x = a.id <=> b.id                                 if x == 0
      x
    end

    # Turn each into a link to show_description, and add optional controls.
    list.map! do |desc|
      any = true
      item = description_link(desc)
      writer = desc.is_writer?(@user) || is_in_admin_mode?
      admin  = desc.is_admin?(@user)  || is_in_admin_mode?
      if writer || admin
        links = []
        links << link_with_query(:EDIT.t, :id => desc.id,
          :controller => obj.show_controller,
          :action => "edit_#{type}_description") if writer
        links << link_with_query(:DESTROY.t,
          { :id => desc.id, :action => "destroy_#{type}_description",
            :controller => obj.show_controller },
          { :confirm => :are_you_sure.t }) if admin
        item += indent + "[" + links.safe_join(' | ') + "]" if links.any?
      end
      item
    end

    if fake_default && !obj.descriptions.select {|d| d.source_type == :public} != []
      str = :description_part_title_public.t
      link = link_with_query(:CREATE.t,
        :controller => obj.show_controller,
        :action => "create_#{type}_description",
        :id => obj.id)
      str += indent + '[' + link + ']'
      list.unshift(str)
    end

    return list
  end

  # Show list of alternate descriptions for show_object page.
  #
  #   <%= show_alt_descriptions(name, projects) %>
  #
  #   # Renders something like this:
  #   <p>
  #     Alternate Descriptions: Create Your Own
  #       Main Description
  #       EOL Project Draft
  #       Rolf's Draft (private)
  #   </p>
  #
  #   <p>
  #     Create New Draft For:
  #       Another Project
  #       One More Project
  #   </p>
  #
  def show_alt_descriptions(obj, projects=nil)
    type = obj.type_tag

    # Show existing drafts, with link to create new one.
    head = content_tag(:big, :show_name_descriptions.t) + ': '
    head += link_with_query(:show_name_create_description.t,
      :controller => obj.show_controller,
      :action => "create_#{type}_description",
      :id => obj.id)
    any = false

    # Add title and maybe "no descriptions", wrapping it all up in paragraph.
    list = list_descriptions(obj).map {|link| indent + link}
    any = list.any?
    list.unshift(head)
    list << indent + "show_#{type}_no_descriptions".to_sym.t if !any
    html = list.safe_join(safe_br)
    html = content_tag(:p, html)

    # Show list of projects user is a member of.
    if projects && projects.length > 0
      head2 = :show_name_create_draft.t + ': '
      list = [head2] + projects.map do |project|
        item = link_with_query(project.title,
          :action => "create_#{type}_description",
          :id => obj.id, :project => project.id,
          :source => 'project')
        indent + item
      end
      html2 = list.safe_join(safe_br)
      html += content_tag(:p, html2)
    end
    return html
  end

  def show_boxed_descriptions(odd_even, obj)
    type = obj.type_tag

    # Show existing drafts, with link to create new one.
    head = "#{:show_name_descriptions.t}: ".html_safe
    head += link_with_query(:show_name_create_description.t,
      :controller => obj.show_controller,
      :action => "create_#{type}_description",
      :id => obj.id)
    any = false

    # Add title and maybe "no descriptions", wrapping it all up in paragraph.
    list = list_descriptions(obj).map {|link| indent + link}
    any = list.any?
    # list.unshift(head)
    list << indent + "show_#{type}_no_descriptions".to_sym.t if !any
    html = list.safe_join(safe_br)
    html = colored_notes_box(odd_even, html)
    head + html
  end

  def show_boxed_projects(odd_even, obj, projects)
    type = obj.type_tag

    # Show list of projects user is a member of.
    head = :show_name_create_draft.t + ': '
    list = projects.map do |project|
      item = link_with_query(project.title,
        :action => "create_#{type}_description",
        :id => obj.id, :project => project.id,
        :source => 'project')
      indent + item
    end
    head.html_safe + colored_notes_box(odd_even, list.safe_join(safe_br))
  end

  def edit_desc_link(desc)
    if desc
      link_with_query(:EDIT.t, :id => desc.id,
        :controller => 'name',
        :action => 'edit_name_description')
    else
      ''
    end
  end

  def edit_best_brief_desc_link(desc)
    edit_desc_link(desc)
  end

  def edit_classification_link(desc)
    edit_desc_link(desc)
  end

  def edit_name_notes_link(name)
    link_with_query(:EDIT.t, :id => name.id,
      :controller => 'name',
      :action => 'edit_name')
  end

  # Just shows the current version number and a link to see the previous.
  #
  #   <%= show_previous_version(name) %>
  #
  #   # Renders just this:
  #   Version: N <br/>
  #   Previous Version: N-1<br/>
  #
  def show_previous_version(obj)
    type = obj.type_tag
    html = "#{:VERSION.t}: #{obj.version}".html_safe
    latest_version = obj.versions.latest
    if (latest_version.merge_source_id rescue false)
      html += indent(1) + get_version_merge_link(obj, latest_version)
    end
    html += safe_br
    if previous_version = latest_version.previous
      html += link_with_query("#{:show_name_previous_version.t}: %d" % previous_version.version,
        :action => "show_past_#{type}", :id => obj.id,
        :version => previous_version.version)
      if (previous_version.merge_source_id rescue false)
        html += indent(1) + get_version_merge_link(obj, previous_version)
      end
      html += safe_br
    end
    return html
  end

  # Show list of past versions for show_past_object pages.
  #
  #   <%= show_past_versions(name) %>
  #
  #   # Renders something like this:
  #   <p>
  #     Other Versions:<br/>
  #       N: Latest Name<br/>
  #       N-1: Previous Name<br/>
  #       ...
  #       1: Original Name<br/>
  #   </p>
  #
  def show_past_versions(obj, args={})
    type = obj.type_tag
    if !@merge_source_id
      versions = obj.versions.reverse
    else
      version_class = "#{obj.class.name}::Version".constantize
      versions = version_class.find_by_sql %(
        SELECT * FROM #{type}s_versions
        WHERE #{type}_id = #{@old_parent_id} AND id <= #{@merge_source_id}
        ORDER BY id DESC
      )
    end
    table = versions.map do |ver|

      # Date change was made.
      date = ver.updated_at.web_date rescue :unknown.t

      # User making the change.
      if user = User.safe_find(ver.user_id)
        user = user_link(user, user.login)
      else
        user = :unknown.t
      end

      # Version number (and name if available).
      link = "#{:VERSION.t} #{ver.version}"
      if ver.respond_to?(:format_name)
        link += ' ' + ver.format_name.t
      end
      if ver.version != obj.version
        if @merge_source_id
          link = link_with_query(link, :controller => obj.show_controller,
            :action => "show_past_#{type}", :id => obj.id,
            :merge_source_id => @merge_source_id,
            :version => version)
        elsif ver == obj.versions.last
          link = link_with_query(link, :controller => obj.show_controller,
            :action => "show_#{type}", :id => obj.id)
        else
          link = link_with_query(link, :controller => obj.show_controller,
            :action => "show_past_#{type}", :id => obj.id,
            :version => ver.version)
        end
      end
      if args[:bold] and args[:bold].call(ver)
        link = content_tag(:b, link)
      end

      # Was this the result of a merge?
      if ver.respond_to?(:merge_source_id)
        merge = get_version_merge_link(obj, ver)
      else
        merge = nil
      end

      i = indent(1)
      [ date, i, user, i, link, i, merge ]
    end
    table = make_table(table, :style => 'margin-left:20px')
    html = content_tag(:p, :VERSIONS.t) + table + safe_br
  end

  # Return link to orphaned versions of old description if this version
  # was the result of a merge.
  def get_version_merge_link(obj, ver)
    type = obj.type_tag
    if ver.merge_source_id and
       (other_ver = ver.class.find(ver.merge_source_id) rescue nil)
      parent_id = other_ver.send("#{type}_id")
      link_with_query(:show_past_version_merged_with.t(:id => parent_id),
        :controller => obj.show_controller,
        :action => "show_past_#{type}", :id => obj.id,
        :merge_source_id => ver.merge_source_id)
    end
  end

  # Show list of authors and editors at the bottom of a show_object page, with
  # the appropriate links for making requests and/or reviewing authors.
  #
  #   <%= show_authors_and_editors(name) %>
  #
  #   # Renders something like this:
  #   <p>
  #     Authors: <user>, <user>, ..., <user> (Request Authorship Credit)<br/>
  #     Editors: <user>, <user>, ..., <user>
  #   </p>
  #
  def show_authors_and_editors(obj)
    type = obj.type_tag

    # Descriptions.
    if type.to_s.match(/description/)
      is_admin = @user && obj.is_admin?(@user)
      authors  = obj.authors
      editors  = obj.editors
      is_author = authors.include?(@user)

      authors = user_list(:show_name_description_author, authors)
      editors = user_list(:show_name_description_editor, editors)

      if is_admin
        authors += safe_nbsp
        authors += link_with_query("(#{:review_authors_review_authors.t})",
          :controller => 'observer',
          :action => 'review_authors', :id => obj.id,
          :type => type)
      elsif !is_author
        authors += safe_nbsp
        authors += link_with_query("(#{:show_name_author_request.t})",
          :controller => 'observer',
          :action => 'author_request', :id => obj.id,
          :type => type)
      end

    # Locations and names.
    else
      editors = obj.versions.map(&:user_id).uniq - [obj.user_id]
      editors = User.all(:conditions => ["id IN (?)", editors])
      authors = user_list(:"show_#{type}_creator", [obj.user])
      editors = user_list(:"show_#{type}_editor", editors)
    end

    return content_tag(:p, authors + safe_br + editors)
  end
  
  ### from textile_sandbox.html.erb ###
  # return escaped html
  # for instance: <i>X</i> => &lt;i&gt;X&lt;/i&gt
  def escape_html(html)
		h(html.to_str)
	end
	
  # From html_helper.rb
  # Replace spaces with safe_nbsp.
  #
  #   <%= button_name.lnbsp %>
  #
  def lnbsp(key)
    key.l.gsub(' ', safe_nbsp)
  end

  # Create an in-line white-space element approximately the given width in
  # pixels.  It should be non-line-breakable, too.
  def indent(w=10)
    "<span style='margin-left:#{w}px'>&nbsp;</span>".html_safe
  end

  # Wrap an html object in '<span title="blah">' tag.  This has the effect of
  # giving it context help (mouse-over popup) in most modern browsers.
  #
  #   <%= add_context_help(link, "Click here to do something.") %>
  #
  def add_context_help(object, help)
    content_tag('span', object, :title => help)
  end

  # Add something to the header from within view.  This can be called as many
  # times as necessary -- the application layout will mash them all together
  # and stick them at the end of the <tt>&gt;head&lt;/tt> section.
  #
  #   <%
  #     add_header(GMap.header)       # adds GMap general header
  #     gmap = make_map(@locations)
  #     add_header(finish_map(gmap))  # adds map-specific header
  #   %>
  #
  def add_header(str)
    @header ||= safe_empty
    @header += str
  end

  # Create a table out of a list of Arrays.
  #
  #   make_table([[1,2],[3,4]])
  #
  # Produces:
  #
  #   <table>
  #     <tr>
  #       <td>1</td>
  #       <td>2</td>
  #     </tr>
  #     <tr>
  #       <td>3</td>
  #       <td>4</td>
  #     </tr>
  #   </table>
  #
  def make_table(rows, table_opts={}, tr_opts={}, td_opts={})
    content_tag(:table, table_opts) do
      rows.map do |row|
        make_row(row, tr_opts, td_opts) + make_line(row, td_opts)
      end.safe_join
    end
  end

  def make_row(row, tr_opts={}, td_opts={})
    content_tag(:tr, tr_opts) do
      if !row.is_a?(Array)
        row
      else
        row.map do |cell|
          make_cell(cell, td_opts)
        end.safe_join
      end
    end
  end

  def make_cell(cell, td_opts={})
    content_tag(:td, cell.to_s, td_opts)
  end

  def make_line(row, td_opts)
    colspan = td_opts[:colspan]
    if colspan
      content_tag(:tr, {:class => 'MatrixLine'}) do
        content_tag(:td, tag(:hr), {:class => 'MatrixLine', :colspan => colspan})
      end
    else
      safe_empty
    end
  end

  # Draw the fancy check-board matrix of objects used, e.g., in list_rss_log.
  # Just pass in a list of objects (and make sure @layout is initialized).
  # It yields for each object, then renders the whole thing.
  #
  #   <%= make_matrix(@objects) do |obj %>
  #     <%= render(obj) %>
  #   <% end %>
  #
  # *NOTE*: You *must* include a <tt><% ... %></tt> within the block somewhere!
  # This is some arcane requirement of +capture+.
  #
  def make_matrix(list, table_opts={}, row_opts={}, col_opts={}, &block)
    rows = []
    cols = []
    for obj in list
      color = calc_color(rows.length, cols.length, @layout['alternate_rows'],
                         @layout['alternate_columns'])
      cols << content_tag(:td, {:align => 'center', :valign => 'top',
                          :class => "ListLine#{color}"}.merge(col_opts)) do
        capture(obj, &block)
      end
      if cols.length >= @layout["columns"]
        rows << cols.safe_join
        cols = []
      end
    end
    rows << cols.safe_join if cols.any?
    table = make_table(rows, {:cellspacing => 0, :class => "Matrix"}.merge(table_opts),
                       row_opts, {:colspan => @layout["columns"]})
    # concat(table)
  end

  # Decide what the color should be for a list item.  Returns 0 or 1.
  # row::       row number
  # col::       column number
  # alt_rows::  from layout_params['alternate_rows']
  # alt_cols::  from layout_params['alternate_columns']
  #
  # (See also ApplicationController#calc_layout_params.)
  #
  def calc_color(row, col, alt_rows, alt_cols)
    color = 0
    if alt_rows
      color = row % 2
    end
    if alt_cols
      if (col % 2) == 1
        color = 1 - color
      end
    end
    color
  end

  # Create a div for notes in Description subclasses.
  #
  #   <%= colored_box(even_or_odd, html) %>
  #
  #   <% colored_box(even_or_odd) do %>
  #     Render stuff in here.  Note lack of "=" in line above.
  #   <% end %>
  #
  def colored_notes_box(even, msg=nil, &block)
    msg = capture(&block) if block_given?
    klass = "ListLine#{even ? 0 : 1}"
    style = [
      'margin-left:10px',
      'margin-right:10px',
      'padding:10px',
      'border:1px dotted',
    ].join(';')
    result = content_tag(:div, msg, class: klass, style: style)
    if block_given?
      concat(result)
    else
      result
    end
  end

  # Wrap some HTML in the cute red/yellow/green box used for +flash[:notice]+.
  #
  #   <%= boxify(2, flash[:notice]) %>
  #
  #   <% boxify(1) do %>
  #     Render more stuff in here.  Note lack of "=" in line above.
  #   <% end %>
  #
  # Notice levels are:
  # 0:: notice (green)
  # 1:: warning (yellow)
  # 2:: error (red)
  #
  def boxify(lvl=0, msg=nil, &block)
    type = "Notices"
    type = "Warnings" if lvl == 1
    type = "Errors"   if lvl == 2
    msg = capture(&block) if block_given?
    content_tag(:div,
      content_tag(:table,
        content_tag(:tr,
          content_tag(:td, msg)),
        class: type),
      style: 'min-width:400px; max-width:800px')
  end

  # From javascript_helper.rb
  # This is a list of modules that are sensitive to order.
  JAVASCRIPT_MODULE_ORDER = %w(
    jquery
    jquery_extensions
  )

  # Schedule javascript modules for inclusion in header.  This is much safer
  # than javascript_include_tag(), since that one is ignorant of whether the
  # given module(s) have been included yet or not, and of correct order.
  #   # Example usage in view template:
  #   <% javascript_include 'name_lister' %>
  def javascript_include(*args)
    if args.select {|arg| arg.class != String} != []
      raise(ArgumentError, "javascript_include doesn't take symbols like :default, etc.")
    end
    @javascripts = [] if !@javascripts
    @javascripts += args
  end

  # This is called in the header section in the layout.  It returns the
  # javascript modules in correct order (see above).
  #   # Example usage in layout header:
  #   <%= sort_javascript_includes.map {|m| javascript_include_tag(m)} %>
  def sort_javascript_includes
    @javascripts = [] if !@javascripts
    # Stick the ones that care about order first, in their preferred order,
    # ignore duplicates since we'll uniq it later anyway.
    @result = JAVASCRIPT_MODULE_ORDER.select do |m|
      @javascripts.include?(m)
    end + @javascripts
    return @result.uniq.map do |m|
      if m.to_s == "jquery"
        # Just user jQuery 1.x for everyone. There is at least one case of
        # version 2.x not working for a fairly modern version of Chrome.
        "jquery_1"
      else
        m
      end
    end
  end

  # Insert a javacsript snippet that causes the browser to focus on a given
  # input field when it loads the page.
  def focus_on(id)
    javascript_tag("document.getElementById('#{id}').focus()")
  end

  # From map_helper.rb
  def make_map(objects, args={})
    args = provide_defaults(args,
      :map_div => 'map_div',
      :controls => [ :large_map, :map_type ],
      :info_window => true
    )
    collection = CollapsibleCollectionOfMappableObjects.new(objects)
    gmap = init_map(args)
    if args[:zoom]
      gmap.center_zoom_init(collection.extents.center, args[:zoom])
    else
      gmap.center_zoom_on_points_init(*collection.representative_points)
    end
    for mapset in collection.mapsets
      draw_mapset(gmap, mapset, args)
    end
    return gmap
  end

  def make_editable_map(object, args={})
    args = provide_defaults(args,
      :editable => true,
      :info_window => false
    )
    gmap = make_map(object, args)
    gmap.event_init(gmap, 'click', 'function(e) {
      clickLatLng(e.latLng);
    }')
    gmap.event_init(gmap, 'dblclick', 'function(e) {
      dblClickLatLng(e.latLng);
    }')
    return gmap
  end

  def make_thumbnail_map(objects, args={})
    args = provide_defaults(args,
      :controls => [ :small_map ],
      :info_window => true,
      :zoom => 2
    )
    return make_map(objects, args)
  end

  def provide_defaults(args, default_args)
    default_args.merge(args)
  end

  def init_map(args={})
    gmap = GM::GMap.new(args[:map_div])
    gmap.control_init(args[:controls].to_boolean_hash)
    return gmap
  end

  def finish_map(gmap)
    ensure_global_header_is_added
    html = gmap.to_html(:no_script_tag => 1)
    js = javascript_tag(html)
    add_header(js)
  end

  def ensure_global_header_is_added
    if !@done_gmap_header_yet
      add_header(GM::GMap.header(:host => MO.domain))
      @done_gmap_header_yet = true
    end
  end

  def draw_mapset(gmap, set, args={})
    title = mapset_marker_title(set)
    marker = GM::GMarker.new(set.center,
      :draggable => args[:editable],
      :title => title
    )
    if args[:info_window]
      marker.info_window = mapset_info_window(set, args)
    end
    if args[:editable]
      map_control_init(gmap, marker, args)
      map_box_control_init(gmap, set, args) if set.is_box?
    else
      gmap.overlay_init(marker)
    end
    if set.is_box?
      draw_box_on_gmap(gmap, set, args)
    end
  end

  def draw_box_on_gmap(gmap, set, args)
    box = GM::GPolyline.new([
      set.north_west,
      set.north_east,
      set.south_east,
      set.south_west,
      set.north_west,
    ], "#00ff88", 3, 1.0)
    if args[:editable]
      box_name = args[:box_name] || 'mo_box'
      gmap.overlay_global_init(box, box_name)
    else
      gmap.overlay_init(box)
    end
  end

  def mapset_marker_title(set)
    result = ''
    strings = map_location_strings(set.objects)
    if strings.length > 1
      result = "#{strings.length} #{:locations.t}"
    else
      result = strings.first
    end
    num_obs = set.observations.length
    if num_obs > 1 and num_obs != strings.length
      num_str = "#{num_obs} #{:observations.t}"
      if strings.length > 1
        result += ", #{num_str}"
      else
        result += " (#{num_str})"
      end
    end
    return result
  end

  def map_location_strings(objects)
    objects.map do |obj|
      if obj.is_location?
        obj.display_name
      elsif obj.is_observation?
        if obj.location
          obj.location.display_name
        elsif obj.lat
          "#{format_latitude(obj.lat)} #{format_longitude(obj.long)}"
        end
      end
    end.reject(&:blank?).uniq
  end

  def mapset_info_window(set, args)
    lines = []
    observations = set.observations
    locations = set.underlying_locations
    lines << mapset_observation_header(set, args) if observations.length > 1
    lines << mapset_location_header(set, args) if locations.length > 1
    lines << mapset_observation_link(observations.first, args) if observations.length == 1
    lines << mapset_location_link(locations.first, args) if locations.length == 1
    lines << mapset_coords(set)
    return lines.safe_join(safe_br)
  end

  def mapset_observation_header(set, args)
    show, map = mapset_submap_links(set, args, :observation)
    map_point_text(:Observations.t, set.observations.length, show, map)
  end

  def mapset_location_header(set, args)
    show, map = mapset_submap_links(set, args, :location)
    map_point_text(:Locations.t, set.underlying_locations.length, show, map)
  end

  def map_point_text(label, count, show, map)
    label.html_safe << ": " << count.to_s << " (" << show << " | " << map << ")"
  end

  def mapset_submap_links(set, args, type)
    params = args[:query_params] || {}
    params = params.merge(:controller => type.to_s.sub('observation','observer'))
    params = params.merge(mapset_box_params(set))
    [ link_to(:show_all.t, params.merge(:action => "index_#{type}")),
      link_to(:map_all.t, params.merge(:action => "map_#{type}s")) ]
  end

  def mapset_observation_link(obs, args)
    link_to("#{:Observation.t} ##{obs.id}", :controller => :observer, :action => :show_observation,
            :id => obs.id, :params => args[:query_params] || {})
  end

  def mapset_location_link(loc, args)
    link_to(loc.display_name.t, :controller => :location, :action => :show_location,
            :id => loc.id, :params => args[:query_params] || {})
  end

  def mapset_box_params(set)
    {
      :north => set.north,
      :south => set.south,
      :east => set.east,
      :west => set.west,
    }
  end

  def mapset_coords(set)
    if set.is_point?
      format_latitude(set.lat) + safe_nbsp + format_longitude(set.long)
    else
      content_tag(:center,
        format_latitude(set.north) + safe_br +
        format_longitude(set.west) + safe_nbsp +
        format_longitude(set.east) + safe_br +
        format_latitude(set.south)
      )
    end
  end

  def format_latitude(val)
    format_lxxxitude(val, 'N', 'S')
  end

  def format_longitude(val)
    format_lxxxitude(val, 'E', 'W')
  end

  def format_lxxxitude(val, dir1, dir2)
    deg = val.abs.round(4)
    return "#{deg}°#{val < 0 ? dir2 : dir1}".html_safe

    # sec = (val.abs * 3600).round
    # min = (sec / 60.0).truncate
    # deg = (min / 60.0).truncate
    # sec -= min * 60
    # min -= deg * 60
    # return "#{deg}°#{min}′#{sec}″#{val < 0 ? dir2 : dir1}"
  end

  def map_control_init(gmap, marker, args, type='ct')
    name = args[:marker_name] || 'mo_marker'
    gmap.overlay_global_init(marker, name + '_' + type)
    gmap.event_init(marker, 'dragend', "function(e) {
      dragEndLatLng(e.latLng, '#{type}')
    }")
  end

  def map_box_control_init(gmap, set, args)
    for point, type in [
      [set.north_west, 'nw'],
      [set.north_east, 'ne'],
      [set.south_west, 'sw'],
      [set.south_east, 'se'],
    ]
      marker = GM::GMarker.new(point, :draggable => true)
      map_control_init(gmap, marker, args, type)
    end
  end

  # From object_link_helper.rb
  # Wrap location name in span: "<span>where (count)</span>"
  #
  #   Where: <%= where_string(obs.place_name) %>
  #
  def where_string(where, count=nil)
    result = where.t
    result += " (#{count})" if count
    result = content_tag(:span, result, class: "Data")
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
    format_user_list(title, users.count, ': ',
      users.map {|u| user_link(u, u.legal_name)}.safe_join(', '))
  end

  def format_user_list(title, user_count, separator, user_block)
    result = safe_empty
    if user_count > 0
      result = (user_count > 1 ? title.to_s.pluralize.to_sym.t : title.t) + separator + user_block
    end
    result
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
      result = link_with_query(result, :controller => desc.show_controller,
        :action => desc.show_action, :id => desc.id)
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
    if image
      url = image.url(size)
    else
      url = Image.url(size, id)
    end

    # Create <img> tag.
    opts = {}
    opts[:border] = args[:border] if args.has_key?(:border)
    opts[:style]  = args[:style]  if args.has_key?(:style)
    str = safe_empty + image_tag(url, opts)
    str += args[:append].to_s

    # Decide what to link it to.
    case link = args[:link] || :show_image
    when :show_image
      link = { :controller => 'image', :action => 'show_image', :id => id }.
        merge(args[:query_params] || query_params)
      link[:obs] = args[:obs] if args.has_key?(:obs)
    when :show_observation
      link = {
        :controller => 'observer',
        :action => 'show_observation',
        :id => args[:obs]
      }.merge(args[:query_params] || query_params)
      raise "missing :obs" if !args.has_key?(:obs)
    when :show_user
      link = { :controller => 'observer', :action => 'show_user',
               :id => args[:user] }
      raise "missing :user" if !args.has_key?(:user)
    when :show_glossary_term
      link = { :controller => 'glossary', :action => 'show_glossary_term',
               :id => args[:glossary_term] }
      raise "missing :glossary_term" if !args.has_key?(:glossary_term)
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
      result += safe_br + content_tag(:div, table, :id => "image_votes_#{id}")
      did_vote_div = true
    end

    # Include original filename.
    if args[:original] and
       image and !image.original_name.blank? and (
         check_permission(image) or
         (image and image.user and image.user.keep_filenames == :keep_and_show)
       )
      result += safe_br unless did_vote_div
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
  def image_copyright(image, div=true)
    link = if image.copyright_holder == image.user.legal_name
      link = user_link(image.user)
    else
      link = image.copyright_holder.to_s.t
    end
    result = image.license.copyright_text(image.year, link)
    if div
      result = content_tag(:div, result, :id => "copytight")
    end
    result
  end

  def export_link(image_id, exported)
    if exported
      link_to_function('Not for Export', "image_export(#{image_id},0)")
    else
      link_to_function('For Export', "image_export(#{image_id},1)")
    end
  end

  def image_exporter(image_id, exported)
    javascript_include('jquery')
    javascript_include('image_export')
    content_tag(:div, export_link(image_id, exported), :id => "image_export_#{image_id}")
  end

  # Render the AJAX vote tabs that go below thumbnails.
  def image_vote_tabs(image, data=nil)
    javascript_include('jquery')
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

    row1 = safe_empty
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
          str = safe_empty
        end
        row1 += content_tag(:td, str, :height => num)
      end
      row1 = content_tag(:tr, row1)
    end

    row2 = safe_empty
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
      str = '&nbsp;|&nbsp;'.html_safe + str if val > 1
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
        link_with_query(:review_ok_for_export.t, :controller => 'observer',
          :action => 'set_export_status', :type => obj.type_tag,
          :id => obj.id, :value => '1')
      end + safe_br +
      if obj.ok_for_export
        link_with_query(:review_no_export.t, :controller => 'observer',
          :action => 'set_export_status', :type => obj.type_tag,
          :id => obj.id, :value => '0')
      else
        content_tag(:b, :review_no_export.t)
      end
    end
  end

  def observation_specimen_info(obs)
    content_tag(:span, observation_specimen_link(obs), class: "Data") + create_specimen_link(obs)
  end

  def observation_specimen_link(obs)
    count = obs.specimens.count
    if count > 0
      link_to(pluralize(count, :specimen.t),
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
      " | ".html_safe + link_with_query(:show_observation_create_specimen.t,
        :controller => 'specimen', :action => 'add_specimen',
        :id => obs.id)
    else
      safe_empty
    end
  end

  # From paginator_helper.rb
  # Wrap a block in pagination links.  Includes letters if appropriate.
  #
  #   <%= paginate_block(@pages) do %>
  #     <% for object in @objects %>
  #       <% object_link(object) %><br/>
  #     <% end %>
  #   <% end %>
  #
  def paginate_block(pages, args={}, &block)
    letters = pagination_letters(pages, args)
    numbers = pagination_numbers(pages, args)
    body = capture(&block).to_s
    content_tag(:div, :class => 'results') do
      letters + numbers + body + numbers + letters
    end
  end

  # Insert letter pagination links.
  #
  #   # In controller:
  #   def action
  #     query = create_query(:Name)
  #     @pages = paginate_letters(:letter, :page, 50)
  #     @names = query.paginate(@pages, :letter_field => 'names.sort_name')
  #   end
  #
  #   # In view:
  #   <%= pagination_letters(@pages) %>
  #   <%= pagination_numbers(@pages) %>
  #
  def pagination_letters(pages, args={})
    if pages and
       pages.letter_arg and
       (pages.letter || pages.num_total > pages.num_per_page) and
       (!pages.used_letters or pages.used_letters.length > 1)
      args = args.dup
      args[:params] = (args[:params] || {}).dup
      args[:params][pages.number_arg] = nil
      str = %w(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z).map do |letter|
        if !pages.used_letters || pages.used_letters.include?(letter)
          pagination_link(letter, letter, pages.letter_arg, args)
        else
          letter
        end
      end.safe_join(' ')
      return content_tag(:div, str, class: "pagination")
    else
      return safe_empty
    end
  end

  # Insert numbered pagination links.  I've thrown out the Rails plugin
  # pagination_letters because it is no longer giving us enough to be worth it.
  # (See also pagination_letters above.)
  #
  #   # In controller:
  #   def action
  #     query = create_query(:Name)
  #     @pages = paginate_numbers(:page, 50)
  #     @names = query.paginate(@pages)
  #   end
  #
  #   # In view: (it is wrapped in 'pagination' div already)
  #   <%= pagination_numbers(@pages) %>
  #
  def pagination_numbers(pages, args={})
    result = safe_empty
    if pages && pages.num_pages > 1
      params = args[:params] ||= {}
      if pages.letter_arg && pages.letter
        params[pages.letter_arg] = pages.letter
      end

      num  = pages.num_pages
      arg  = pages.number_arg
      this = pages.number
      this = 1 if this < 1
      this = num if this > num
      size = args[:window_size] || 5
      from = this - size
      to   = this + size

      result = []
      pstr = "« #{:PREV.t}"
      nstr = "#{:NEXT.t} »"
      result << pagination_link(pstr, this-1, arg, args) if this > 1
      result << '|'                                      if this > 1
      result << pagination_link(1, 1, arg, args)         if from > 1
      result << '...'                                    if from > 2
      for n in from..to
        if n == this
          result << n
        elsif n > 0 && n <= num
          result << pagination_link(n, n, arg, args)
        end
      end
      result << '...'                                    if to < num - 1
      result << pagination_link(num, num, arg, args)     if to < num
      result << '|'                                      if this < num
      result << pagination_link(nstr, this+1, arg, args) if this < num

      result = content_tag(:div, result.safe_join(' '), :class => "pagination")
    end
    result
  end

  # Render a single pagination link for paginate_numbers above.
  def pagination_link(label, page, arg, args)
    params = args[:params] || {}
    params[arg] = page
    url = reload_with_args(params)
    if args[:anchor]
      url.sub!(/#.*/, '')
      url += '#' + args[:anchor]
    end
    link_to(label, url)
  end

  # Take URL that got us to this page and add one or more parameters to it.
  # Returns new URL.
  #
  # link_to("Next Page", reload_with_args(:page => 2))
  def reload_with_args(new_args)
    uri = request.url.sub(/^\w+:\/+[^\/]+/, '')
    add_args_to_url(uri, new_args)
  end

  # Take an arbitrary URL and change the parameters. Returns new URL. Should
  # even handle the fancy "/object/id" case. (Note: use +nil+ to mean delete
  # -- i.e. <tt>add_args_to_url(url, :old_arg => nil)</tt> deletes the
  # parameter named +old_arg+ from +url+.)
  #
  # url = url_for(:action => "blah", ...)
  # new_url = add_args_to_url(url, :arg1 => :val1, :arg2 => :val2, ...)
  def add_args_to_url(url, new_args)
    new_args = new_args.clone
    args = {}

    # Garbage in, garbage out...
    return url if !url.valid_encoding?

    # Parse parameters off of current URL.
    addr, parms = url.split('?')
    for arg in parms ? parms.split('&') : []
      var, val = arg.split('=')
      if var && var != ''
        var = CGI.unescape(var)
        # See note below about precedence in case of redundancy.
        args[var] = val if !args.has_key?(var)
      end
    end

    # Deal with the special "/xxx/id" case.
    if addr.match(/\/(\d+)$/)
      new_id = new_args[:id] || new_args['id']
      addr.sub!(/\d+$/, new_id.to_s) if new_id
      new_args.delete(:id)
      new_args.delete('id')
    end

    # Merge in new arguments, deleting where new values are nil.
    for var in new_args.keys
      val = new_args[var]
      var = var.to_s
      if val.nil?
        args.delete(var)
      elsif val.is_a?(ActiveRecord::Base)
        args[var] = val.id.to_s
      else
        args[var] = CGI.escape(val.to_s)
      end
    end

    # Put it back together.
    return addr if args.keys == []
    return addr + '?' + args.keys.sort.map \
        {|k| CGI.escape(k) + '=' + (args[k] || "")}.join('&')
  end

  # From tab_helper.rb
  # Render a set of tabs for the prev/index/next links.
  def draw_prev_next_tabs(object, mappable=false)
    type = object.type_tag
    new_tab_set do
      args = add_query_param({
        :controller => object.show_controller,
        :id         => object.id,
      })
      add_tab("« #{:BACK.t}",  args.merge(:action => "prev_#{type}" ))
      add_tab(:INDEX.t, args.merge(:action => "index_#{type}"))
      if mappable
        add_tab_with_query(:MAP.t, :controller => 'location',
          :action => 'map_locations')
      end
      add_tab("#{:FORWARD.t} »",  args.merge(:action => "next_#{type}"  ))
    end
  end

  # Create a new set of tabs.  Use like this:
  #
  #   new_tab_set do
  #     add_tab('Bare String')
  #     add_tab('Hard-Coded Link', '/name/show_name/123')
  #     add_tab('External Link', 'http://images.google.com/')
  #     add_tab('Normal Link', :action => :blah, :id => 123, ...)
  #     add_tab('Dangerous Link', { :action => :destroy, :id => 123 },
  #                               { :confirm => :are_you_sure.l })
  #   end
  #
  # Tab sets now support headers.  Syntaxes allowed are:
  #
  #   new_tab_set
  #   new_tab_set("Header:")
  #   new_tab_set("Header:", [tab1, tab2, ...])
  #   new_tab_set([tab1, tab2, ...]) # (no header)
  #
  # These render like:
  #
  #   Header: link1 | link2 | link3 | ...
  #
  def new_tab_set(header=nil, tabs=nil, &block)
    header, tabs = nil, header if header.is_a?(Array)
    if tabs && tabs.empty?
      new_set = nil
    else
      @tab_sets ||= []
      @tab_sets.push(new_set = [header])
      add_tabs(tabs) if tabs
      yield(new_set) if block
    end
    return new_set
  end

  # Add custom-made tab set.
  def custom_tab_set(set)
    @tab_sets ||= []
    @tab_sets.push(set)
  end

  # Change the header of the open tab set.
  def set_tab_set_header(header)
    if @tab_sets and @tab_sets.last
      @tab_sets.last.first = header
    else
      raise(RuntimeError, 'You forgot to call new_tab_set().')
    end
  end

  # Add zero or more tabs to an open tab set.  See +new_tab_set+.
  def add_tabs(tabs)
    if tabs.is_a?(Array)
      for tab in tabs
        add_tab(*tab)
      end
    end
  end

  # Add a tab to an open tab set.  See +new_tab_set+.
  def add_tab(*args)
    if @tab_sets and @tab_sets.last
      @tab_sets.last.push(args)
    else
      raise(RuntimeError, 'You must place add_tab() calls inside a new_tab_set() block.')
    end
  end

  # Add a tab to an open tab set.  See +new_tab_set+.
  def add_tab_with_query(name, params, html=nil)
    add_tab(name, add_query_param(params), html)
  end

  # Render tab sets in upper left of page body.  (Only used by app layout.)
  def render_tab_sets
    if @tab_sets
      @tab_sets.map do |set|
        if set.is_a?(Array)
          render_tab_set(*set)
        else
          set.to_s
        end
      end.safe_join
    end
  end

  # Render one tab set in upper left of page body.  (Only used by
  # +render_tab_sets+.)
  def render_tab_set(header, *links)
    header += ' ' if header
    content_tag(:div, :class => 'tab_set') do
      all_tabs = links.map do |tab|
        render_tab(*tab)
      end
      header.to_s.html_safe + all_tabs.safe_join(' | ') + safe_br
    end
  end

  # Render a tab in HTML.  Used in: app/views/layouts/application.rb
  def render_tab(label, link_args=nil, html_args={})
    if !link_args
      result = label
    elsif link_args.is_a?(String) && (link_args[0..6] == 'http://')
      result = content_tag(:a, label, :href => link_args, :target => :_new)
    else
      if link_args.is_a?(Hash) && link_args.has_key?(:help)
        help = link_args[:help]
        link_args = link_args.dup
        link_args.delete(:help)
      elsif html_args and html_args.has_key?(:help)
        help = html_args[:help]
        html_args = html_args.dup
        html_args.delete(:help)
      else
        help = nil
      end
      link = link_to(label, link_args, html_args)
      link = add_context_help(link, help) if help
      result = link
    end
    return result
  end

  ##############################################################################
  #
  #  :section: Right Tabs
  #
  ##############################################################################

  # Draw the cutesy eye icons in the upper right side of screen.  It does it
  # by creating a "right" tab set.  Thus this must be called in the header of
  # the view and must not actually be rendered.  Typical usage would be:
  #
  #   # At top of view:
  #   <%
  #     # Specify the page's title.
  #     @title = "Page Title"
  #
  #     # Define set of linked text tabs for top-left.
  #     new_tab_set do
  #       add_tab("Tab Label One", :link => args, ...)
  #       add_tab("Tab Label Two", :link => args, ...)
  #       ...
  #     end
  #
  #     # Draw interest icons in the top-right.
  #     draw_interest_icons(@object)
  #   %>
  #
  # This will cause the set of three icons to be rendered floating in the
  # top-right corner of the content portion of the page.
  #
  def draw_interest_icons(object)
    if @user
      type = object.type_tag

      # Create link to change interest state.
      def interest_link(label, object, state) #:nodoc:
        link_with_query(label,
          :controller => 'interest',
          :action => 'set_interest',
          :id => object.id,
          :type => object.class.name,
          :state => state
        )
      end

      # Create large icon image.
      def interest_icon_big(type, alt) #:nodoc:
        image_tag("#{type}2.png",
          :alt => alt,
          :width => '50px',
          :height => '50px',
          :class => 'interest_big',
          :title => alt
        )
      end

      # Create small icon image.
      def interest_icon_small(type, alt) #:nodoc:
        image_tag("#{type}3.png",
          :alt => alt,
          :width => '23px',
          :height => '23px',
          :class => 'interest_small',
          :title => alt
        )
      end

      def interest_tab(img1, img2, img3)
        content_tag(:div, img1 + safe_br + img2 + img3)
      end

      case @user.interest_in(object)
      when :watching
        alt1 = :interest_watching.l(:object => type.l)
        alt2 = :interest_default_help.l(:object => type.l)
        alt3 = :interest_ignore_help.l(:object => type.l)
        img1 = interest_icon_big('watch', alt1)
        img2 = interest_icon_small('halfopen', alt2)
        img3 = interest_icon_small('ignore', alt3)
        img2 = interest_link(img2, object, 0)
        img3 = interest_link(img3, object, -1)

      when :ignoring
        alt1 = :interest_ignoring.l(:object => type.l)
        alt2 = :interest_watch_help.l(:object => type.l)
        alt3 = :interest_default_help.l(:object => type.l)
        img1 = interest_icon_big('ignore', alt1)
        img2 = interest_icon_small('watch', alt2)
        img3 = interest_icon_small('halfopen', alt3)
        img2 = interest_link(img2, object, 1)
        img3 = interest_link(img3, object, 0)

      else
        alt1 = :interest_watch_help.l(:object => type.l)
        alt2 = :interest_ignore_help.l(:object => type.l)
        img1 = interest_icon_small('watch', alt1)
        img2 = interest_icon_small('ignore', alt2)
        img1 = interest_link(img1, object, 1)
        img2 = interest_link(img2, object, -1)
        img3 = ''
      end
      add_right_tab(interest_tab(img1, img2, img3))
    end
  end

  # Add tab to float off to the right of the main tabs.  There is only one
  # set of these, arranged vertically.
  def add_right_tab(html)
    @right_tabs ||= []
    @right_tabs.push(html)
  end

  def add_location_search_tabs(name)
    search_string = name.gsub(' Co.', ' County').gsub(', USA', '').gsub(' ', '+').gsub(',', '%2C')
    add_tab('Google Maps', 'http://maps.google.com/maps?q=' + search_string)
    add_tab('Yahoo Maps', 'http://maps.yahoo.com/#mvt=m&q1=' + search_string)
    add_tab('Wikipedia', 'http://en.wikipedia.org/w/index.php?title=Special:Search&search=' + search_string)
    add_tab('Google Search', 'http://www.google.com/search?q=' + search_string)
  end

  # From textile_helper.rb
  # Override Rails method of the same name.  Just calls our
  # Textile#textilize_without_paragraph method on the given string.
  def textilize_without_paragraph(str, do_object_links=false)
    Textile.textilize_without_paragraph(str, do_object_links)
  end

  # Override Rails method of the same name.  Just calls our Textile#textilize
  # method on the given string.
  def textilize(str, do_object_links=false)
    Textile.textilize(str, do_object_links)
  end
end

# From description_helper.rb
def name_section_link(title, data, query)
  if data and data != 0
    link_to(title,
     add_query_param({:controller => 'observer',
       :action => 'index_observation'}, query)) + safe_br
  end
end
