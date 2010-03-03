#
#  = Application Helpers
#
#  These methods are available to all templates in the application:
#
#  ==== Localization
#  rank_as_string::         Translate :Genus into "Genus" (localized).
#  rank_as_lower_string::   Translate :Genus into "genus" (localized).
#  rank_as_plural_string::  Translate :Genus into "Genera" (localized).
#  quality_as_string::      Translate image quality into localized String.
#  review_as_string::       Translate review status into localized String.
#
#  ==== Common Info Blocks
#  show_previous_version::  Show version number and link to previous.
#  show_embedded_description_title:: Show description title with edit/destroy links.
#  show_alt_descriptions::  Show list of alt descriptions for show_object page.
#  show_past_versions::     Show list of versions for show_past_object page.
#  show_authors_and_editors:: Show list of authors and editors below desc page.
#  show_object_footer::     Show the created/modified/view dates and RSS log.
#
################################################################################

module ApplicationHelper
  require_dependency 'auto_complete_helper'
  require_dependency 'html_helper'
  require_dependency 'javascript_helper'
  require_dependency 'map_helper'
  require_dependency 'object_link_helper'
  require_dependency 'paginator_helper'
  require_dependency 'tab_helper'
  require_dependency 'textile_helper'

  include AutoComplete
  include HTML
  include Javascript
  include Map
  include ObjectLink
  include Paginator
  include Tabs
  include Textile

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
    "RANK_#{rank.to_s.upcase}".to_sym.l
  end

  # Translate Name rank (singular).
  #
  #   rank_as_lower_string(:genus)  -->  "genus"
  #
  def rank_as_lower_string(rank)
    "rank_#{rank.to_s.downcase}".to_sym.l
  end

  # Translate Name rank (plural).
  #
  #   rank_as_plural_string(:genus)  -->  "Genera"
  #
  def rank_as_plural_string(rank)
    "RANK_PLURAL_#{rank.to_s.upcase}".to_sym.l
  end

  # Translate Name rank (plural).
  #
  #   rank_as_plural_string(:genus)  -->  "genera"
  #
  def rank_as_lower_plural_string(rank)
    "rank_plural_#{rank.to_s.downcase}".to_sym.l
  end

  # Translate image quality.
  #
  #   quality_as_string(:high)  -->  "Excellent"
  #
  def quality_as_string(val)
    "quality_#{val}".to_sym.l
  end

  # Translate review status.
  #
  #   review_as_string(:unvetted)  -->  "Reviewed"
  #
  def review_as_string(val)
    "review_#{val}".to_sym.l
  end

  ##############################################################################
  #
  #  :section: Common Info Blocks
  #
  ##############################################################################

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
    html = ''
    html += "#{:VERSION.t}: #{obj.version}<br/>\n"
    if previous_version = obj.find_version(-2)
      html += link_to("#{:show_name_previous_version.t}: %d" % previous_version,
                      :action => "show_past_#{type}", :id => obj.id,
                      :version => previous_version,
                      :params => query_params) + "<br/>\n"
    end
    return html
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
    if @user
      head += link_to(:show_name_create_description.t,
                      :action => "create_#{type}_description",
                      :id => obj.id, :params => query_params)
    end
    any = false
    list = [head] + obj.descriptions.select do |desc|
      desc.has_any_notes?  or
      (desc.user == @user) or
      is_reviewer          or
      (desc.source_type == :public)
    end.map do |desc|
      any = true
      item = description_link(desc)
      if (desc.user == @user) or is_in_admin_mode?
        item += indent + '['
        item += link_to(:EDIT.t, :id => desc.id, :params => query_params,
                        :action => "edit_#{type}_description")
        item += ' | '
        item += link_to(:DESTROY.t, { :id => desc.id,
                        :action => "destroy_#{type}_description",
                        :params => query_params },
                        { :confirm => :are_you_sure.t })
        item += ']'
      end
      indent + item
    end
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
    html = obj.versions.reverse.map do |v|
      line = "#{v.version}: #{v.display_name.t}"
      if v.version != obj.version
        if v == obj.versions.last
          line = link_to(line, :controller => obj.show_controller,
                         :action => "show_#{type}", :id => obj.id,
                         :params => query_params)
        else
          line = link_to(line, :controller => obj.show_controller,
                         :action => "show_past_#{type}", :id => obj.id,
                         :version => v.version, :params => query_params)
        end
      end
      if args[:bold] and args[:bold].call(v)
        line = '<b>' + line + '</b>'
      end
      indent + line
    end
    html.unshift("#{:VERSIONS.t}:")
    html = '<p style="white-space:nowrap">' + html.join("<br/>\n") + '</p>'
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
    type = obj.class.name.underscore
    num_versions = obj.respond_to?(:version) ? obj.versions.length : 0

    # Old version of versioned object.
    if num_versions > 0 && obj.version < num_versions
      html << :footer_version_out_of.t(:num => obj.version,
                                    :total => num_versions)
      html << :footer_modified_by.t(:user => user_link(obj.user),
                                 :date => obj.modified.web_time) if obj.modified

    # Latest version or non-versioned object.
    else
      if num_versions > 0
        latest_user = User.find(obj.versions.latest.user_id)
        html << :footer_created_by.t(:user => user_link(obj.user),
                                  :date => obj.created.web_time) if obj.created
        html << :footer_last_modified_by.t(:user => user_link(latest_user),
                                        :date => obj.modified.web_time) if obj.modified
      else
        html << :footer_created_at.t(:date => obj.created.web_time) if obj.created
        html << :footer_last_modified_at.t(:date => obj.modified.web_time) if obj.modified
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

    html = html.join("<br/>\n")
    html = '<span class="Date">' + html + '</span>'
    html = '<p>' + html + '</p>'
  end
end
