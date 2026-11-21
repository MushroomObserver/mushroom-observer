# frozen_string_literal: true

# Per-description icons strip rendered in the heading-links slot of
# the description details panel: Edit / Destroy / Clone / Move /
# Merge / Adjust Permissions / Make Default / Project / Publish.
# Each entry is a `Tab::Description::*` PORO rendered via
# `Components::Link::Get`, gated by user permissions and description
# state.
#
# Spaced via `Components::InlineLinkBlock` -- the same gap-based
# spacing every other inline icon strip in the app uses (title-bar
# edit/delete, `Components::InlineCRUDLinks`), rather than literal
# " | " separators.
class Components::Description::ModLinks < Components::Base
  prop :description, ::Description
  prop :user, _Nilable(::User), default: nil

  def view_template
    icons = icon_components
    return if icons.empty?

    InlineLinkBlock(items: icons)
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
    Components::Button.new(type: :delete, target: @description,
                           variant: :strip,
                           class: Components::InlineLinkBlock.item_class)
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
    unless tab.html_options[:button]
      return Components::Link.new(
        type: :get, tab: tab,
        class: item_class(tab.html_options[:class])
      )
    end

    method = tab.html_options[:button]
    opts = tab.html_options
    Components::Button.new(type: method,
                           name: opts[:title] || tab.title,
                           target: tab.path,
                           icon: opts[:icon],
                           confirm: opts[:confirm],
                           variant: :strip,
                           class: item_class)
  end

  def item_class(*extra)
    class_names("stateful-link", Components::InlineLinkBlock.item_class, *extra)
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
