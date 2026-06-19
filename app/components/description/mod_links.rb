# frozen_string_literal: true

# Per-description icons strip rendered in the heading-links slot of
# the description details panel: Edit / Destroy / Clone / Move /
# Merge / Adjust Permissions / Make Default / Project / Publish.
# Each entry is a `Tab::Description::*` PORO rendered via
# `Components::Link::Icon`, gated by user permissions and description
# state.
#
# Sibling-in-spirit to `Components::Link::InlineMod` (the bracketed
# `[edit | destroy]` strip that sits next to records in obs-show
# sub-panels), but distinct in shape: this one is the icon row
# attached to the panel heading, with " | " separators rather than
# brackets.
class Components::Description::ModLinks < Components::Base
  prop :description, ::Description
  prop :user, _Nilable(::User), default: nil

  def view_template
    icons = icon_components
    return if icons.empty?

    icons.each_with_index do |component, idx|
      plain(" | ") if idx.positive?
      render(component)
    end
  end

  private

  def icon_components
    [
      edit_icon,
      (destroy_icon if admin?),
      *admin_icons,
      *state_icons
    ].compact
  end

  def edit_icon
    return unless writer?

    icon_from_tab(::Tab::Description::Edit.new(description: @description))
  end

  def destroy_icon
    Components::CrudButton::Delete.new(target: @description, btn: nil)
  end

  def admin_icons
    icons = [icon_from_tab(::Tab::Description::Clone.new(
                             description: @description
                           ))]
    return icons unless admin?

    icons << icon_from_tab(::Tab::Description::Move.new(
                             description: @description
                           ))
    icons << icon_from_tab(::Tab::Description::Merge.new(
                             description: @description
                           ))
    if parent_type == :name
      icons << icon_from_tab(::Tab::Description::AdjustPermissions.new(
                               description: @description
                             ))
    end
    icons
  end

  def state_icons
    [make_default_icon, project_icon, publish_icon].compact
  end

  def make_default_icon
    return unless @user && @description.public &&
                  @description.parent.description_id != @description.id

    icon_from_tab(::Tab::Description::MakeDefault.new(
                    description: @description
                  ))
  end

  def project_icon
    return unless @description.source_type == "project" &&
                  @description.source_object

    icon_from_tab(::Tab::Description::Project.new(
                    description: @description
                  ))
  end

  def publish_icon
    return unless admin? && parent_type == :name &&
                  @description.source_type != :public

    icon_from_tab(::Tab::Description::PublishDraft.new(
                    description: @description
                  ))
  end

  def icon_from_tab(tab)
    content, path, opts = tab.to_a
    Components::Link::Icon.new(content, path, **(opts || {}))
  end

  # -- predicates -------------------------------------------------

  def writer?
    @description.writer?(@user) || in_admin_mode?
  end

  def admin?
    @description.is_admin?(@user) || in_admin_mode?
  end

  def parent_type
    @description.parent.type_tag
  end
end
