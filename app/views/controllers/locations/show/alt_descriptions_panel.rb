# frozen_string_literal: true

# "Descriptions" panel on the Location show page. Renders the
# `Views::Controllers::Descriptions::List` inside a
# `Components::Panel`; the panel heading carries a "create new
# description" icon-link. When the caller passes a `projects:`
# array, appends a "create draft for project" row at the bottom.
module Views::Controllers::Locations
  class Show
    class AltDescriptionsPanel < Views::Base
      prop :user, _Nilable(::User), default: nil
      prop :object, ::Location
      prop :projects, _Nilable(_Array(::Project)), default: nil
      # Forwarded to `Descriptions::List#current` (typed there as
      # `_Nilable(::Description)`). The currently-shown description
      # of the parent Location, used to suppress its self-link in
      # the alts list.
      prop :current, _Nilable(::Description), default: nil

      def view_template
        render(Components::Panel.new(panel_id: "alt_descriptions")) do |panel|
          panel.with_heading { :show_name_descriptions.l }
          panel.with_heading_links { heading_links }
          panel.with_body { render_body }
        end
      end

      private

      def heading_links
        Link(type: :icon,
             tab: Tab::Description::Create.new(parent: @object))
      end

      def render_body
        render(Views::Controllers::Descriptions::List.new(
                 user: @user, object: @object, type: @object.type_tag,
                 current: @current,
                 empty_text: :"show_#{@object.type_tag}_no_descriptions".t
               ))
        render_projects_list if @projects.present?
      end

      def render_projects_list
        p do
          plain("#{:show_name_create_draft.l}: ")
          @projects.each do |project|
            br
            tab = Tab::Description::NewForProject.new(
              parent: @object, project: project
            ).to_a
            a(href: tab[1], class: class_names("ml-3", tab[2][:class])) do
              plain(tab[0])
            end
          end
        end
      end
    end
  end
end
