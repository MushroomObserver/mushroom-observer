#
#  = Description Helpers
#
#  A bunch of high-level helpers for description-related views.
#
#  == Methods
#
#  show_description_tab_set:: Create tabs for show_description page.
#  show_alt_descriptions::    Show list of alt descriptions for show_object page.
#  show_embedded_description_title:: Show description title with edit/destroy links.
#  show_previous_version::    Show version number and link to previous.
#  show_past_versions::       Show list of versions for show_past_object page.
#  show_authors_and_editors:: Show list of authors and editors below desc page.
#
##############################################################################

module ApplicationHelper::Description

  # Create tabs for show_description page.
  def show_description_tab_set(desc)
    type = desc.class.name.underscore.sub(/_description/, '')
    writer = desc.is_writer?(@user) || is_in_admin_mode?
    admin  = desc.is_admin?(@user)  || is_in_admin_mode?
    new_tab_set do
      if true
        add_tab(:show_object.t(:type => type.to_sym), :action => "show_#{type}",
                :id => desc.parent_id, :params => query_params)
      end
      if writer
        add_tab(:show_description_edit.t,
                :action => "edit_#{type}_description", :id => desc.id,
                :params => query_params)
      end
      if admin
        add_tab(:show_description_destroy.t,
                { :action => 'destroy_#{type}_description',
                :id => desc.id, :params => query_params },
                { :confirm => :are_you_sure.l })
      end
      if true
        add_tab(:show_description_clone.t, :controller => type,
                :action => "create_#{type}_description", :id => desc.parent_id,
                :clone => desc.id, :params => query_params,
                :help => :show_description_clone_help.l)
      end
      if admin
        add_tab(:show_description_merge.t, :action => 'merge_descriptions',
                :id => desc.id, :params => query_params,
                :help => :show_description_merge_help.l)
      end
      if (desc.source_type != :public) and (@user == desc.user)
        add_tab(:show_description_publish.t, :action => 'publish_description',
                :id => desc.id, :params => query_params,
                :help => :show_description_publish_help.l)
      end
      if admin
        add_tab(:show_description_adjust_permissions.t,
                :action => 'adjust_permissions', :id => @description.id,
                :params => query_params,
                :help => :show_description_adjust_permissions_help.l)
      end
      if @user && (desc.parent.description_id != desc.id)
        add_tab(:show_description_make_default.t,
                :action => 'make_description_default', :id => desc.id,
                :params => query_params,
                :help => :show_description_make_default_help.l)
      end
    end
  end

  # Header of the embedded description within a show_object page.
  #
  #   <%= show_embedded_description_title(desc, name) %>
  #
  #   # Renders something like this:
  #   <p>EOL Project Draft: Show | Edit | Destroy</p>
  #
  def show_embedded_description_title(desc, parent)
    type = desc.class.name.underscore
    title = description_title(desc)
    links = []
    if @user && desc.is_writer?(@user)
      links << link_to(:EDIT.t, :id => desc.id, :action => "edit_#{type}",
                       :params => query_params)
    end
    if @user && desc.is_admin?(@user)
      links << link_to(:DESTROY.t, :id => desc.id,
                       :action => "destroy_#{type}", :params => query_params)
    end
    '<p><big>' + title + ':</big> ' + links.join(' | ') + '</p>'
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
    type = obj.class.name.underscore

    # Show existing drafts, with link to create new one.
    head = "<big>#{:show_name_descriptions.t}:</big> "
    head += link_to(:show_name_create_description.t,
                    :action => "create_#{type}_description",
                    :id => obj.id, :params => query_params)
    any = false

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
        item += indent + '['
        item += link_to(:EDIT.t, :id => desc.id, :params => query_params,
                        :action => "edit_#{type}_description") if writer
        item += ' | '
        item += link_to(:DESTROY.t, { :id => desc.id,
                        :action => "destroy_#{type}_description",
                        :params => query_params },
                        { :confirm => :are_you_sure.t }) if admin
        item += ']'
      end
      indent + item
    end

    # Add title and maybe "no descriptions", wrapping it all up in paragraph.
    list.unshift(head)
    list << indent + "show_#{type}_no_descriptions".to_sym.t if !any
    html = list.join("<br/>\n")
    html = '<p style="white-space:nowrap">' + html + '</p>'

    # Show list of projects user is a member of.
    if projects && projects.length > 0
      head2 = :show_name_create_draft.t + ': '
      list = [head2] + projects.map do |project|
        item = link_to(project.title,
                       :action => "create_#{type}_description",
                       :id => obj.id, :project => project.id,
                       :source => 'project', :params => query_params)
        indent + item
      end
      html2 = list.join("<br/>\n")
      html += '<p style="white-space:nowrap">' + html2 + '</p>'
    end
    return html
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
    type = obj.class.name.underscore
    html = "#{:VERSION.t}: #{obj.version}"
    latest_version = obj.versions.latest
    if (latest_version.merge_source_id rescue false)
      html += indent(1) + get_version_merge_link(obj, latest_version)
    end
    html += "<br/>\n"
    if previous_version = latest_version.previous
      html += link_to("#{:show_name_previous_version.t}: %d" % previous_version.version,
                      :action => "show_past_#{type}", :id => obj.id,
                      :version => previous_version,
                      :params => query_params)
      if (previous_version.merge_source_id rescue false)
        html += indent(1) + get_version_merge_link(obj, previous_version)
      end
      html += "<br/>\n"
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
    type = obj.class.name.underscore
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
      date = ver.modified.web_date rescue :unknown.t

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
          link = link_to(link, :controller => obj.show_controller,
                         :action => "show_past_#{type}", :id => obj.id,
                         :merge_source_id => @merge_source_id,
                         :version => version, :params => query_params)
        elsif ver == obj.versions.last
          link = link_to(link, :controller => obj.show_controller,
                         :action => "show_#{type}", :id => obj.id,
                         :params => query_params)
        else
          link = link_to(link, :controller => obj.show_controller,
                         :action => "show_past_#{type}", :id => obj.id,
                         :version => ver.version, :params => query_params)
        end
      end
      if args[:bold] and args[:bold].call(ver)
        link = '<b>' + link + '</b>'
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
    html = "<p>#{:VERSIONS.t}:</p>#{table}<br/>"
  end

  # Return link to orphaned versions of old description if this version
  # was the result of a merge.
  def get_version_merge_link(obj, ver)
    type = obj.class.name.underscore
    if ver.merge_source_id and
       (other_ver = ver.class.find(ver.merge_source_id) rescue nil)
      parent_id = other_ver.send("#{type}_id")
      link_to(:show_past_version_merged_with.t(:id => parent_id),
              :controller => obj.show_controller,
              :action => "show_past_#{type}", :id => obj.id,
              :merge_source_id => ver.merge_source_id,
              :params => query_params)
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
    type = obj.class.name.underscore

    # Descriptions.
    if type.match(/description/)
      is_admin = @user && obj.is_admin?(@user)
      authors  = obj.authors
      editors  = obj.editors
      is_author = authors.include?(@user)

      authors = user_list(:show_name_description_author, authors)
      editors = user_list(:show_name_description_editor, editors)

      if is_admin
        authors += '&nbsp;'
        authors += link_to("(#{:review_authors_review_authors.t})",
                           :controller => 'observer',
                           :action => 'review_authors', :id => obj.id,
                           :type => type, :params => query_params)
      elsif !is_author
        authors += '&nbsp;'
        authors += link_to("(#{:show_name_author_request.t})",
                           :controller => 'observer',
                           :action => 'author_request', :id => obj.id,
                           :type => type, :params => query_params)
      end

    # Locations and names.
    else
      editors = obj.versions.map(&:user_id).uniq - [obj.user_id]
      editors = User.all(:conditions => ["id IN (?)", editors])
      authors = user_list(:"show_#{type}_creator", [obj.user])
      editors = user_list(:"show_#{type}_editor", editors)
    end

    return "<p>#{authors}<br/>#{editors}</p>"
  end
end
