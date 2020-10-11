# frozen_string_literal: true

module FooterHelper
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
    if /description/.match?(type.to_s)
      authors   = obj.authors
      editors   = obj.editors
      is_admin  = @user && obj.is_admin?(@user)
      is_author = @user && authors.include?(@user)

      authors = user_list(:show_name_description_author, authors)
      editors = user_list(:show_name_description_editor, editors)

      if is_admin
        authors += safe_nbsp
        authors += link_with_query("(#{:review_authors_review_authors.t})",
                                   controller: :observer,
                                   action: :review_authors,
                                   id: obj.id, type: type)
      elsif !is_author
        authors += safe_nbsp
        authors += link_with_query("(#{:show_name_author_request.t})",
                                   controller: :observer,
                                   action: :author_request,
                                   id: obj.id, type: type)
      end

    # Locations and names.
    else
      editors = obj.versions.map(&:user_id).uniq - [obj.user_id]
      editors = User.where(id: editors).to_a
      authors = user_list(:"show_#{type}_creator", [obj.user])
      editors = user_list(:"show_#{type}_editor", editors)
    end

    content_tag(:p, authors + safe_br + editors)
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
    num_versions = obj.respond_to?(:version) ? obj.versions.length : 0

    # Old version of versioned object.
    if num_versions.positive? && obj.version < num_versions
      html << :footer_version_out_of.t(num: obj.version, total: num_versions)
      if obj.updated_at
        html << :footer_updated_by.t(user: user_link(obj.user),
                                     date: obj.updated_at.web_time)
      end

    # Latest version of non-versioned object.
    else
      if num_versions.positive?
        latest_user = User.safe_find(obj.versions.latest.user_id)
        if obj.created_at
          html << :footer_created_by.t(user: user_link(obj.user),
                                       date: obj.created_at.web_time)
        end
        if latest_user && obj.updated_at
          html << :footer_last_updated_by.t(user: user_link(latest_user),
                                            date: obj.updated_at.web_time)
        elsif obj.updated_at
          html << :footer_last_updated_at.t(date: obj.updated_at.web_time)
        end
      else
        if obj.created_at
          html << :footer_created_at.t(date: obj.created_at.web_time)
        end
        if obj.updated_at
          html << :footer_last_updated_at.t(date: obj.updated_at.web_time)
        end
      end
      if obj.respond_to?(:num_views) && obj.last_view
        times = if obj.old_num_views == 1
                  :one_time.l
                else
                  :many_times.l(num: obj.old_num_views)
                end
        date = obj.old_last_view&.web_time || :footer_never.l
        html << :footer_viewed.t(date: date, times: times)
      end
      if User.current && obj.respond_to?(:last_viewed_by)
        time = obj.old_last_viewed_by(User.current)&.web_time || :footer_never.l
        html << :footer_last_you_viewed.t(date: time)
      end
    end

    # Show RSS log for all of the above.
    if obj.respond_to?(:rss_log_id) && obj.rss_log_id
      html << link_to(:show_object.t(type: :log),
                      controller: :observer,
                      action: :show_rss_log,
                      id: obj.rss_log_id)
    end

    html = html.safe_join(safe_br)
    tag.p(html, class: "small footer-view-stats")
  end
end
