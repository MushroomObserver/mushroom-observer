# frozen_string_literal: true

module Views::Controllers::GlossaryTerms::Images
  # Bulk image-removal form: shows a matrix of images with a
  # checkbox under each, plus matching top/bottom submit buttons.
  # The controller action receives `params[:selected][image_id] =
  # "yes"` for selected images (and `"no"` for unselected, via the
  # hidden sidecar).
  #
  # Lives under the nested glossary_terms/images controller subtree
  # since a GlossaryTerm is the only model this is wired up for today.
  #
  # @param model [::GlossaryTerm] the parent object
  # @param user [User] current user (passed through to InteractiveImage)
  class RemoveForm < ::Components::ApplicationForm
    prop :model, ::GlossaryTerm, :positional
    prop :user, ::User

    def initialize(model, **attrs)
      # PUT request; Superform handles `_method` hidden field.
      super(model, method: :put, **attrs)
    end

    def view_template
      super do
        submit_remove
        render_image_matrix
        submit_remove
      end
    end

    private

    def form_action
      detach_image_from_glossary_term_path(model.id)
    end

    def submit_remove
      submit(:image_remove_remove.l, center: true)
    end

    def render_image_matrix
      render(Components::Matrix::Table.new) do
        model.images.each { |image| render_image_cell(image) }
      end
    end

    def render_image_cell(image)
      render(Components::Matrix::Box.new(id: image.id)) do
        div(class: "py-3 text-center") { render_image_preview(image) }
        div(class: "pb-3 text-center") { render_select_checkbox(image) }
      end
    end

    def render_image_preview(image)
      InteractiveImage(
        user: @user,
        image: image,
        original: true,
        votes: false,
        extra_classes: "image-to-remove"
      )
    end

    # `selected[<image_id>]` with `"yes"`/`"no"` matches the existing
    # controller's expected param structure (see
    # `glossary_terms/images_controller.rb#detach`). Wraps each
    # checkbox in MO's standard `.checkbox` BS3 markup.
    def render_select_checkbox(image)
      checkbox_field("selected[#{image.id}]",
                     label: "#{:image.l} ##{image.id}",
                     wrap_class: "my-0",
                     checked_value: "yes",
                     unchecked_value: "no")
    end
  end
end
