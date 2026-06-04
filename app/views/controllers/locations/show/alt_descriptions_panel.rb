# frozen_string_literal: true

# "Descriptions" panel on the Location show page. Renders the
# `Views::Controllers::Descriptions::List` (with `<br>` separators —
# matches the pre-Phlex `safe_join(safe_br)` shape) inside a
# `Components::Panel`; the panel heading carries a "create new
# description" icon-link. When the caller passes a `projects:`
# array, appends a "create draft for project" row at the bottom.
# Replaces `_alt_descriptions_panel.html.erb`.
module Views::Controllers::Locations::Show
  class AltDescriptionsPanel < Views::Base
    prop :user, _Nilable(::User), default: nil
    prop :object, ::Location
    prop :projects, _Nilable(_Array(::Project)), default: nil
    prop :current, _Nilable(_Any), default: nil

    def view_template
      render(Components::Panel.new(panel_id: "alt_descriptions")) do |panel|
        panel.with_heading { :show_name_descriptions.l }
        panel.with_heading_links { heading_links }
        panel.with_body { render_body }
      end
    end

    INDENT = '<span class="ml-3">&nbsp;</span>'.html_safe

    private

    def heading_links
      content, path, opts = Tab::Description::Create.new(parent: @object).to_a
      render(Components::IconLink.new(content, path, **opts))
    end

    def render_body
      render(Views::Controllers::Descriptions::List.new(
               user: @user, object: @object, type: @object.type_tag,
               current: @current, separator: :br,
               empty_text: empty_text
             ))
      render_projects_list if @projects.present?
    end

    def empty_text
      INDENT + :"show_#{@object.type_tag}_no_descriptions".t
    end

    def render_projects_list
      p do
        plain("#{:show_name_create_draft.l}: ")
        @projects.each do |project|
          br
          trusted_html(INDENT)
          tab = Tab::Description::NewForProject.new(
            parent: @object, project: project
          ).to_a
          a(href: tab[1], **tab[2].except(:icon)) { plain(tab[0]) }
        end
      end
    end
  end
end
