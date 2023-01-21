# frozen_string_literal: true

# helpers which create html which links to prior version(s)
module VersionsHelper
  # Just shows the current version number and a link to see the previous.
  #
  #   <%= show_previous_version(name) %>
  #
  #   # Renders just this:
  #   Version: N <br/>
  #   Previous Version: N-1<br/>
  #
  def show_previous_version(obj)
    previous_version = obj.versions.latest&.previous
    if previous_version
      previous_version_link(previous_version, obj)
    else
      initial_html(obj)
    end
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
    table = make_table(build_version_table(obj, args), class: "ml-4")
    tag.p(:VERSIONS.t) + table + safe_br
  end

  private

  def previous_version_link(previous_version, obj)
    str = :show_name_previous_version.t + " " + previous_version.version.to_i
    initial_html(obj) +
      link_with_query(str,
                      controller: "#{obj.show_controller}/versions",
                      action: :show, id: obj.id,
                      version: previous_version.version) +
      safe_br
  end

  def initial_html(obj)
    :VERSION.t + ": " + obj.version.to_s + safe_br
  end

  def build_version_table(obj, args)
    obj.versions.reverse.map do |ver|
      [find_ver_date(ver), indent,
       find_ver_user(ver), indent,
       calc_link(obj, ver, args), indent]
    end
  end

  def calc_link(obj, ver, args)
    link = query_link(obj, ver, initial_link(ver))
    if args[:bold]&.call(ver)
      content_tag(:b, link)
    else
      link
    end
  end

  def find_ver_date(ver)
    ver.updated_at.web_date
  rescue StandardError
    :unknown.t
  end

  def find_ver_user(ver)
    user = User.safe_find(ver.user_id)
    return :unknown.t unless user

    user_link(user, user.login)
  end

  def link_to_ver(link, ver, obj)
    if ver == obj.versions.last
      link_with_query(link, controller: obj.show_controller,
                            action: obj.show_action,
                            id: obj.id)
    else
      link_with_query(link,
                      controller: "#{obj.show_controller}/versions",
                      action: :show, id: obj.id,
                      version: ver.version)
    end
  end

  def initial_link(ver)
    link = "#{:VERSION.t} #{ver.version}"
    return link unless ver.respond_to?(:format_name)

    link + " #{ver.format_name.t}"
  end

  def query_link(obj, ver, link)
    return link if ver.version != obj.version

    if ver == obj.versions.last
      link_with_query(link, controller: obj.show_controller,
                            action: obj.show_action,
                            id: obj.id)
    else
      link_with_query(link,
                      controller: "#{obj.show_controller}/versions",
                      action: :show, id: obj.id,
                      version: ver.version)
    end
  end
end
