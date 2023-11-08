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
      initial_version_html(obj)
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
    table = make_table(rows: build_version_table(obj, args),
                       table_opts: { class: "mb-0" })
    panel = tag.div(table, class: "panel-body")
    tag.strong("#{:VERSIONS.t}:") +
      tag.div(panel, class: "panel panel-default")
  end

  private

  def previous_version_link(previous_version, obj)
    str = "#{:show_name_previous_version.t} #{previous_version.version}"
    initial_version_html(obj) +
      link_with_query(str,
                      { controller: "#{obj.show_controller}/versions",
                        action: :show, id: obj.id,
                        version: previous_version.version },
                      class: "previous_version_link") +
      safe_br
  end

  def initial_version_html(obj)
    :VERSION.t + ": " + obj.version.to_s + safe_br
  end

  def build_version_table(obj, args)
    obj.versions.reverse.map do |ver|
      [find_version_date(ver),
       find_version_user(ver),
       link_to_version(initial_version_link_text(ver, args), ver, obj)]
    end
  end

  def find_version_date(ver)
    ver.updated_at.web_date
  rescue StandardError
    :unknown.t
  end

  def find_version_user(ver)
    user = User.safe_find(ver.user_id)
    return :unknown.t unless user

    user_link(user, user.login)
  end

  def link_to_version(text, ver, obj)
    if ver == obj.versions.last
      link_with_query(text, obj.show_link_args, class: "latest_version_link")
    else
      link_with_query(text,
                      { controller: "#{obj.show_controller}/versions",
                        action: :show, id: obj.id,
                        version: ver.version },
                      class: "initial_version_link")
    end
  end

  def initial_version_link_text(ver, args)
    text = "#{:VERSION.t} #{ver.version}"
    text = tag.strong(text) if args[:bold]&.call(ver)
    return text unless ver.respond_to?(:display_name)

    # keep this out of the above `strong` tag, because it has its own tags
    [text, safe_br, ver.display_name.t].safe_join
  end
end
