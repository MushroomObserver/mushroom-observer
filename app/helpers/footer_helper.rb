# frozen_string_literal: true

module FooterHelper
  # Show list of authors and editors at the bottom of a show_object page, with
  # the appropriate links for making requests and/or reviewing authors.
  #
  #   <%= show_authors_and_editors(obj: name, user: @user) %>
  #
  #   # Renders something like this:
  #   <p>
  #     Authors: <user>, <user>, ..., <user> (Request Authorship Credit)<br/>
  #     Editors: <user>, <user>, ..., <user>
  #   </p>
  #
  # New: Must pass in @versions to avoid these and other helpers doing
  # duplicate version lookups, which are slow.
  def show_authors_and_editors(obj:, versions:, user:)
    type = obj.type_tag

    authors, editors = if /description/.match?(type.to_s)
                         html_description_authors_and_editors(obj, user)
                       else
                         html_undescribed_obj_authors_and_editors(obj, versions)
                       end

    content_tag(:p, authors + safe_br + editors)
  end

  ###############################################################

  private

  def html_description_authors_and_editors(obj, user)
    authors   = obj.authors
    editors   = obj.editors
    is_admin  = user && obj.is_admin?(user)
    is_author = user && authors.include?(user)

    authors = user_list(:show_name_description_author, authors)
    editors = user_list(:show_name_description_editor, editors)

    if is_admin
      authors = authors_plus_review_authors(obj, authors)
    elsif !is_author
      authors = authors_plus_author_request(obj, authors)
    end

    [authors, editors]
  end

  def authors_plus_review_authors(obj, authors)
    authors += safe_nbsp
    authors += link_with_query(
      "(#{:review_authors_review_authors.t})",
      authors_review_path(id: obj.id, type: obj.type_tag)
    )
    authors
  end

  def authors_plus_author_request(obj, authors)
    authors += safe_nbsp
    authors += link_with_query(
      "(#{:review_authors_review_authors.t})",
      authors_review_path(id: obj.id, type: obj.type_tag)
    )
    authors
  end

  def html_undescribed_obj_authors_and_editors(obj, versions)
    type = obj.type_tag

    editors = versions.map(&:user_id).uniq - [obj.user_id]
    editors = User.where(id: editors).to_a
    authors = user_list(:"show_#{type}_creator", [obj.user])
    editors = user_list(:"show_#{type}_editor", editors)

    [authors, editors]
  end

  ###############################################################

  public

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
  def show_object_footer(obj, versions = [])
    num_versions = versions.length

    html = if num_versions.positive? && obj.version < num_versions
             html_for_old_version_of_versioned_object(obj, num_versions)
           else
             html_for_latest_version_or_non_versioned_object(obj, versions)
           end

    html.concat(link_to_rss_log(obj))
    html = html.safe_join(safe_br)
    tag.p(html, class: "small footer-view-stats mt-3")
  end

  ###############################################################

  private

  def html_for_old_version_of_versioned_object(obj, num_versions)
    html = [:footer_version_out_of.t(num: obj.version, total: num_versions)]
    return html unless obj.updated_at

    html << :footer_updated_by.t(user: user_link(obj.user_id),
                                 date: obj.updated_at.web_time)
  end

  def link_to_rss_log(obj)
    if obj.respond_to?(:rss_log_id) && obj.rss_log_id
      [link_to(:show_object.t(type: :log), activity_log_path(obj.rss_log_id))]
    else
      []
    end
  end

  def html_for_latest_version_or_non_versioned_object(obj, versions)
    html = if versions.length.positive?
             html_for_latest_version(obj, versions)
           else
             html_for_non_versioned_object(obj)
           end

    html << html_num_views(obj) if obj.respond_to?(:num_views) && obj.last_view

    if User.current && obj.respond_to?(:last_viewed_by)
      html << html_last_viewed_by(obj)
    end

    html
  end

  def html_for_latest_version(obj, versions)
    # This is yet another db lookup of users - let's try skipping it.
    # latest_user = User.safe_find(versions.latest.user_id)
    html = html_created_by(obj)

    if versions.latest.user_id && obj.updated_at
      html << :footer_last_updated_by.t(
        user: user_link(versions.latest.user_id),
        date: obj.updated_at.web_time
      )
    elsif obj.updated_at
      html << :footer_last_updated_at.t(date: obj.updated_at.web_time)
    end

    html
  end

  def html_created_by(obj)
    if obj.created_at
      [:footer_created_by.t(user: user_link(obj.user_id),
                            date: obj.created_at.web_time)]
    else
      []
    end
  end

  def html_for_non_versioned_object(obj)
    html = []
    if obj.created_at
      html << :footer_created_at.t(date: obj.created_at.web_time)
    end
    # following condition is not covered
    if obj.updated_at
      html << :footer_last_updated_at.t(date: obj.updated_at.web_time)
    end
    html
  end

  def html_num_views(obj)
    times = if obj.old_num_views == 1
              :one_time.l
            else
              :many_times.l(num: obj.old_num_views)
            end
    date = obj.old_last_view&.web_time || :footer_never.l
    :footer_viewed.t(date: date, times: times)
  end

  # only for obs
  def html_last_viewed_by(obj)
    time = obj.old_last_viewed_by(User.current)&.web_time || :footer_never.l
    :footer_last_you_viewed.t(date: time)
  end
end
