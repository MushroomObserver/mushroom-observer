module VersionHelper
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
    if latest_version.respond_to?(:merge_source_id) &&
       latest_version.merge_source_id
      html += indent(1) + get_version_merge_link(obj, latest_version)
    end
    html += safe_br
    return html unless latest_version

    if previous_version = latest_version.previous
      str = :show_name_previous_version.t + " " + previous_version.version.to_i
      html += link_with_query(str, action: "show_past_#{type}", id: obj.id,
                                   version: previous_version.version)
      if previous_version.respond_to?(:merge_source_id) &&
         previous_version.merge_source_id
        html += indent(1) + get_version_merge_link(obj, previous_version)
      end
      html += safe_br
    end
    html
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
  def show_past_versions(obj, args = {})
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
      date = begin
               ver.updated_at.web_date
             rescue StandardError
               :unknown.t
             end

      # User making the change.
      user = if user = User.safe_find(ver.user_id)
               user_link(user, user.login)
             else
               :unknown.t
             end

      # Version number (and name if available).
      link = "#{:VERSION.t} #{ver.version}"
      link += " " + ver.format_name.t if ver.respond_to?(:format_name)
      if ver.version != obj.version
        if @merge_source_id
          link = link_with_query(link, controller: obj.show_controller,
                                       action: "show_past_#{type}", id: obj.id,
                                       merge_source_id: @merge_source_id,
                                       version: version)
        elsif ver == obj.versions.last
          link = link_with_query(link, controller: obj.show_controller,
                                       action: "show_#{type}", id: obj.id)
        else
          link = link_with_query(link, controller: obj.show_controller,
                                       action: "show_past_#{type}", id: obj.id,
                                       version: ver.version)
        end
      end
      link = content_tag(:b, link) if args[:bold]&.call(ver)

      # Was this the result of a merge?
      merge = if ver.respond_to?(:merge_source_id)
                get_version_merge_link(obj, ver)
              end

      i = indent(1)
      [date, i, user, i, link, i, merge]
    end

    table = make_table(table, style: "margin-left:20px")
    html = content_tag(:p, :VERSIONS.t) + table + safe_br
  end

  # Return link to orphaned versions of old description if this version
  # was the result of a merge.
  def get_version_merge_link(obj, ver)
    type = obj.type_tag
    if ver.merge_source_id &&
       (other_ver = begin
                      ver.class.find(ver.merge_source_id)
                    rescue StandardError
                      nil
                    end)
      parent_id = other_ver.send("#{type}_id")
      link_with_query(:show_past_version_merged_with.t(id: parent_id),
                      controller: obj.show_controller,
                      action: "show_past_#{type}",
                      id: obj.id,
                      merge_source_id: ver.merge_source_id)
    end
  end
end
