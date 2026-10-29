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
    prop :user, ::User
    prop :licenses, _Array(Array)
    prop :projects, _Array(::Project), default: -> { [] }
    prop :submitted_project_ids, _Nilable(_Array(Integer)),
         default: nil, &TO_ID_ARRAY

    # Explicit form action — `image_path(model)` via the
    # `observations/images` controller. PUT update.
    def form_action
      image_path(model)
    end

    def view_template
      super do
        render_image_fields
        render_project_checkboxes if @projects.any?
        render_footer_buttons
      end
    end

    private

    def render_image_fields
      text_field(:copyright_holder,
                 label: :form_images_copyright_holder)
      text_field(:original_name,
                 label: :form_images_original_name)
      date_field(:when, inline: true,
                        label: :form_images_when_taken,
                        help: :form_images_when_help.t,
                        help_collapse: true)
      select_field(:license_id, @licenses,
                   label: :license.ti,
                   help: :form_images_license_help.t,
                   help_collapse: true)
      # Two-paragraph help: notes-specific + textile-syntax help.
      textarea_field(:notes,
                     label: :notes.ti,
                     help: textile_help,
                     help_collapse: true,
                     data: { autofocus: true })
    end

    def textile_help
      parts = ["<p>#{:form_images_notes_help.t}</p>",
               "<p>#{:shared_textile_help.l}</p>"]
      parts.join.html_safe # rubocop:disable Rails/OutputSafety
    end

    def render_project_checkboxes
      render(
        Components::Form::CheckboxPanel.new(
          form: self,
          type: :project,
          form_object_name: "image",
          objects: @projects,
          checked_ids: checked_project_ids,
          disabled_ids: disabled_project_ids,
          help_text: :form_images_project_help.t
        )
      )
    end

    def checked_project_ids
      @submitted_project_ids || model.project_ids
    end

    # The image's owner can always toggle membership; non-owners can
    # only toggle projects they're already members of.
    def disabled_project_ids
      return [] if model.user_id == @user.id

      @projects.reject { |project| project.member?(@user) }.map(&:id)
    end

    def render_footer_buttons
      div(class: "text-center mt-3 mb-5") do
        submit(:save_edits.ti)
        Button(
          type: :get,
          name: :cancel_and_show.t(type: :image),
          target: image_path(model.id),
          class: "ml-2"
        )
      end
    end
  end
end
