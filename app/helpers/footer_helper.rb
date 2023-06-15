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
  def show_authors_and_editors(obj:, user:)
    type = obj.type_tag

    authors, editors = if /description/.match?(type.to_s)
                         html_description_authors_and_editors(obj, user)
                       else
                         html_undescribed_obj_authors_and_editors(obj)
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

  def html_undescribed_obj_authors_and_editors(obj)
    type = obj.type_tag

    editors = obj.versions.map(&:user_id).uniq - [obj.user_id]
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
  def show_object_footer(obj)
    num_versions = obj.respond_to?(:version) ? obj.versions.length : 0

    html = if num_versions.positive? && obj.version < num_versions
             html_for_old_version_of_versioned_object(obj, num_versions)
           else
             html_for_latest_version_or_non_versioned_object(obj, num_versions)
           end

    html.concat(link_to_rss_log(obj))

    # header_els = []
    # header_els << tag.span(:RSS_LOG.t, class: "font-weight-bold")
    # # Show RSS log for all of the above.
    # if obj.respond_to?(:rss_log_id) && obj.rss_log_id
    #   header_els << link_to(activity_log_path(obj.rss_log_id),
    #                         class: "btn btn-sm btn-link") do
    #     concat(tag.span(:show_object.t(type: :log), class: "mr-1"))
    #     concat(icon("fa-regular", "list-ul", class: "fa-sm"))
    #   end
    # end
    # tags = []
    # tags << tag.div(class: "row-justified") { header_els.safe_join }
    # tags << tag.p(class: "small my-0") { html.safe_join(safe_br) }

    tag.div(class: "footer-view-stats small my-0") { html.safe_join(safe_br) }
  end

  ###############################################################

  private

  def html_for_old_version_of_versioned_object(obj, num_versions)
    html = [:footer_version_out_of.t(num: obj.version, total: num_versions)]
    return html unless obj.updated_at

    html << :footer_updated_by.t(user: user_link(obj.user),
                                 date: obj.updated_at.web_time)
  end

  def link_to_rss_log(obj)
    if obj.respond_to?(:rss_log_id) && obj.rss_log_id
      [tag.div(class: "d-flex text-right") do
        link_to(
          activity_log_path(obj.rss_log_id),
          class: "small",
          aria: { label: :show_object.t(type: :log) },
          data: { toggle: "tooltip", placement: "top",
                  title: :show_object.t(type: :log) }
        ) do
          concat(tag.span(:show_object.t(type: :log), class: "sr-only"))
          concat(icon("fa-regular", "list-ul", class: "fa-lg"))
        end
      end]
    else
      []
    end
  end

  def html_for_latest_version_or_non_versioned_object(obj, num_versions)
    html = if num_versions.positive?
             html_for_latest_version(obj)
           else
             html_for_non_versioned_object(obj)
           end

    html << html_num_views(obj) if obj.respond_to?(:num_views) && obj.last_view

    if User.current && obj.respond_to?(:last_viewed_by)
      html << html_last_viewed_by(obj)
    end

    html
  end

  def html_for_latest_version(obj)
    latest_user = User.safe_find(obj.versions.latest.user_id)
    html = html_created_by(obj)

    if latest_user && obj.updated_at
      html << :footer_last_updated_by.t(user: user_link(latest_user),
                                        date: obj.updated_at.web_time)
    elsif obj.updated_at
      html << :footer_last_updated_at.t(date: obj.updated_at.web_time)
    end

    html
  end

  def html_created_by(obj)
    if obj.created_at
      [:footer_created_by.t(user: user_link(obj.user),
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

  def html_last_viewed_by(obj)
    time = obj.old_last_viewed_by(User.current)&.web_time || :footer_never.l
    :footer_last_you_viewed.t(date: time)
  end
end
