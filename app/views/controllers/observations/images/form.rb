# frozen_string_literal: true

# Phlex Superform for editing an observation Image (date, license,
# copyright, notes, projects). Rendered by
# `Observations::ImagesController#edit`.
#
# Wire shape for project membership: `image[project_ids][]=<id>` —
# Rails-idiomatic has_many-through array (`Image has_many :projects,
# through: :project_images`). The controller's
# `update_related_projects` iterates a union of the user's member
# projects plus the obs's projects (so users uploading to an obs in
# a project they don't belong to can still attach the image), then
# toggles each one based on whether its id is in the submitted array.
module Views::Controllers::Observations::Images
  class Form < ::Components::ApplicationForm
    # Render state is bundled into the `**state` splat so the init
    # stays under Metrics/ParameterLists. Callers still pass each
    # piece as a named kwarg (projects:, submitted_project_ids:).
    def initialize(image, user:, licenses:, **state)
      @user = user
      @licenses = licenses
      @projects = state[:projects] || []
      @submitted_project_ids = state[:submitted_project_ids]
      super(image, **state.except(:projects, :submitted_project_ids))
    end

    # Explicit form action — `image_path(model)` via the
    # `observations/images` controller. PUT update.
    def form_action
      image_path(model)
    end

    def view_template
      super do
        submit(:SAVE_EDITS.l, center: true)
        render_image_fields
        render_project_checkboxes if @projects.any?
        render_footer_buttons
      end
    end

    private

    def render_image_fields
      text_field(:copyright_holder,
                 label: "#{:form_images_copyright_holder.t}:")
      text_field(:original_name,
                 label: "#{:form_images_original_name.t}:")
      date_field(:when, inline: true,
                        label: "#{:form_images_when_taken.l}:",
                        help: :form_images_when_help.t)
      select_field(:license_id, @licenses,
                   label: "#{:LICENSE.t}:",
                   help: :form_images_license_help.t)
      # Two-paragraph help: notes-specific + textile-syntax help.
      textarea_field(:notes,
                     label: "#{:NOTES.t}:",
                     help: textile_help,
                     data: { autofocus: true })
    end

    def textile_help
      parts = ["<p>#{:form_images_notes_help.t}</p>",
               "<p>#{:shared_textile_help.l}</p>"]
      parts.join.html_safe # rubocop:disable Rails/OutputSafety
    end

    def render_project_checkboxes
      div(class: "form-group") do
        p(class: "font-weight-bold") { plain("#{:PROJECTS.t}:") }
        div(class: "help-note mr-3") do
          trusted_html(:form_images_project_help.t)
        end
        div(class: "form-group") do
          # Sentinel: ensures `image[project_ids]` is always present in
          # params even when every checkbox is unchecked (Rack drops
          # empty arrays). Controller `compact_blank`s this empty value.
          input(type: "hidden", name: "image[project_ids][]",
                value: "", autocomplete: "off")
          @projects.each { |project| render_project_checkbox(project) }
        end
      end
    end

    def render_project_checkbox(project)
      checkbox_field(:project_ids,
                     label: false,
                     disabled: cannot_modify_project?(project)) do |cb|
        cb.option(project.id,
                  checked: project_checked?(project.id)) do
          whitespace
          render(Components::Link::Object.new(object: project))
        end
      end
    end

    def render_footer_buttons
      div(class: "text-center mt-3 mb-5") do
        submit(:SAVE_EDITS.l)
        render(Components::Button.new(
                 type: :get,
                 name: :cancel_and_show.t(type: :image),
                 target: image_path(model.id),
                 class: "ml-2"
               ))
      end
    end

    # Only the image owner
    # or a member of the project can toggle.
    def cannot_modify_project?(project)
      model.user_id != @user.id && !project.member?(@user)
    end

    def project_checked?(project_id)
      if @submitted_project_ids
        @submitted_project_ids.map(&:to_i).include?(project_id.to_i)
      else
        model.project_ids.include?(project_id)
      end
    end
  end
end
