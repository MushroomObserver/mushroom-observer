# frozen_string_literal: true

# Action template for `Observations::ImagesController#edit` — the
# "edit observation image" page. Renders `Images::Form` alongside a
# `Components::Image::Interactive` preview of the image being edited.
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

      div(class: "row") do
        div(class: class_names(Grid::SM8, "col-md-6 col-lg-4")) { render_form }
        div(class: class_names(Grid::SM4, "col-md-6 col-lg-8")) do
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
      render(::Components::Image::Interactive.new(
               user: @user,
               image: @image,
               size: :medium,
               votes: true
             ))
    end
  end
end
