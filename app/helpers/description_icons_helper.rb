# frozen_string_literal: true

# Inline icon-link strips for the description details panel — Edit /
# Destroy / Clone / Move / Merge / Adjust Permissions / Make Default /
# Project / Publish. Each helper renders `Tab::Description::*` POROs
# via `icon_link_to`, gated by user permissions and description state.
module DescriptionIconsHelper
  def description_mod_links(user, desc, _type)
    links = []
    if user_writer?(user, desc)
      links << icon_link_to(*Tab::Description::Edit.new(description: desc).to_a)
    end
    links << destroy_button(target: desc, btn: nil) if user_is_admin?(
      user, desc
    )
    links
  end

  def description_change_links(user, desc)
    type = desc.parent.type_tag
    admin = user_is_admin?(user, desc)
    [
      description_edit_icon(user, desc),
      (destroy_button(target: desc, btn: nil) if admin),
      description_admin_icons(desc, type, admin),
      description_state_icons(user, desc, type, admin)
    ].flatten.compact_blank.safe_join(" | ")
  end

  def description_edit_icon(user, desc)
    return unless user_writer?(user, desc)

    icon_link_to(*Tab::Description::Edit.new(description: desc).to_a)
  end

  def description_admin_icons(desc, type, admin)
    icons = [icon_link_to(*Tab::Description::Clone.new(description: desc).to_a)]
    return icons unless admin

    icons << icon_link_to(*Tab::Description::Move.new(description: desc).to_a)
    icons << icon_link_to(*Tab::Description::Merge.new(description: desc).to_a)
    if type == :name
      icons << icon_link_to(
        *Tab::Description::AdjustPermissions.new(description: desc).to_a
      )
    end
    icons
  end

  def description_state_icons(user, desc, type, admin)
    [
      description_make_default_icon(user, desc),
      description_project_icon(desc),
      description_publish_icon(desc, type, admin)
    ].compact
  end

  def description_make_default_icon(user, desc)
    return unless user && desc.public &&
                  desc.parent.description_id != desc.id

    icon_link_to(*Tab::Description::MakeDefault.new(description: desc).to_a)
  end

  def description_project_icon(desc)
    return unless desc.source_type == "project" && desc.source_object

    icon_link_to(*Tab::Description::Project.new(description: desc).to_a)
  end

  def description_publish_icon(desc, type, admin)
    return unless admin && type == :name && desc.source_type != :public

    icon_link_to(*Tab::Description::PublishDraft.new(description: desc).to_a)
  end
end
