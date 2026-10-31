# frozen_string_literal: true

# Right-column panel on a description show page: the parent's other
# descriptions (visible ones, including this one) plus the UI to
# start a new project-sourced draft. Split out of the old
# DetailsAndAltsPanel's "alts" column (#5527 review) -- it's a
# separate concept from the description's detail/notes/authors
# panels, not part of "Detail".
module Views::Controllers::Descriptions
  class OtherDescriptionsPanel < Views::Base
    prop :description, ::Description
    prop :user, _Nilable(::User), default: nil
    prop :incoming_project, _Nilable(::Project), default: nil

    def view_template
      Panel(panel_id: "other_descriptions") do |panel|
        panel.with_heading { panel_title }
        panel.with_heading_links { render_create_link }
        panel.with_body { render_body }
        panel.with_footer { render_new_draft_form }
      end
    end

    private

    def parent
      @description.parent
    end

    def parent_type
      parent.type_tag
    end

    def panel_title
      :show_description_list_title.t(type: parent_type)
    end

    def render_create_link
      name, target, opts = ::Tab::Description::Create.new(
        parent: parent
      ).to_a
      Link(type: :get, name: name, target: target,
           **(opts || {}))
    end

    def render_body
      render(List.new(
               user: @user, object: parent, type: parent_type,
               current: @description, empty_text: alts_empty_text
             ))
    end

    def render_new_draft_form
      render(Components::Description::NewDraftForm.new(
               target: parent, project: @incoming_project
             ))
    end

    def alts_empty_text
      show_no_descriptions_as_string(parent_type)
    end
  end
end
