# frozen_string_literal: true

# helpers which create html which links to prior version(s).
#
# `show_previous_version` + its private composers were replaced by
# `Components::PreviousVersion` — see that component for the
# "Version: N / Previous Version" line. Only the version-table
# composers remain here (consumed by `_version_table.erb`).
module VersionsHelper
  private

  def build_version_table(obj, versions, args)
    versions.reverse.map do |ver|
      [find_version_date(ver),
       find_version_user(ver),
       link_to_version(
         initial_version_link_text(ver, args), ver, obj, versions
       )]
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

  def link_to_version(text, ver, obj, versions)
    if ver == versions.last
      link_to(text, obj.show_link_args, class: "latest_version_link")
    else
      link_to(text,
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
