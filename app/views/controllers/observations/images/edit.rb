# frozen_string_literal: true

# Action template for `Observations::ImagesController#edit` — the
# "edit observation image" page. Renders `Images::Form` alongside a
# `Components::InteractiveImage` preview of the image being edited.
module Views::Controllers::Observations::Images
  class Edit < Views::FullPageBase
    prop :image, ::Image
    prop :licenses, _Array(Array)
    prop :projects, _Array(::Project), default: -> { [] }
    prop :submitted_project_ids, _Nilable(_Array(String)), default: nil
    prop :user, _Nilable(::User), default: nil

    def view_template
      add_edit_title(@image)
      add_context_nav(::Tab::Observation::ImagesEdit.new(image: @image))
      container_class(:wide)

      Row do
        Column(xs: 12, sm: 8, md: 6, lg: 4) { render_form }
        Column(xs: 12, sm: 4, md: 6, lg: 8) do
          render_image_preview
        end
      end
    end

    private

    def render_form
      render(Form.new(
               @image,
               user: @user,
               licenses: @licenses,
               projects: @projects,
               submitted_project_ids: @submitted_project_ids
             ))
    end

    def render_image_preview
      InteractiveImage(
        user: @user,
        image: @image,
        size: :medium,
        votes: true
      )
    end
  end
end
