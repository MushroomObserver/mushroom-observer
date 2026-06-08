# frozen_string_literal: true

# "Reuse an existing image" form rendered by the `reuse` action of
# `Observations::ImagesController`, `Account::Profile::ImagesController`,
# and `GlossaryTerms::ImagesController`. Replaces the
# `app/views/controllers/shared/_images_to_reuse.erb` partial.
#
# Two parts: a small Rails-form-builder form that takes an Image id
# and POSTs to `form_action[:controller]#attach`; below it, a
# `paginated_results`-wrapped `Components::MatrixTable` of clickable
# thumbnails (each wrapping `Components::InteractiveImage` in a POST
# link to `attach` so a click attaches that image).
#
# Data (the paginated `objects:` and `pagination_data:`) is loaded by
# the controller via `ImageReusable#load_images_to_reuse` — this
# view does not query.
#
# Inherits from `Views::Base` (not `Components::Base`) for the
# `paginated_results` page-chrome helper.
module Views::Controllers::Shared
  class ImagesToReuseForm < Views::Base
    include Phlex::Rails::Helpers::FormWith

    prop :form_action, Hash
    prop :user, _Nilable(::User), default: nil
    prop :objects, _Any
    prop :pagination_data, _Any
    prop :all_users, _Boolean, default: false

    def view_template
      render_id_form
      render_image_matrix
    end

    private

    def render_id_form
      form_with(url: @form_action, method: :post) do
        div(class: "container-text") do
          render_id_field_row
          div(class: "help-block form-group") do
            trusted_html(:image_reuse_id_help.tp)
          end
          render_toggle_link
        end
      end
    end

    def render_id_field_row
      div(class: "form-group form-inline") do
        label(for: "img_id") { plain("#{:image_reuse_id.t}:") }
        input(type: "text", name: "img_id", id: "img_id", size: 8,
              class: "form-control", data: { autofocus: "true" })
        input(type: "submit", name: "commit",
              value: :image_reuse_reuse.l,
              class: "btn btn-default ml-3")
      end
    end

    def render_toggle_link
      div(class: "form-group mt-3") do
        link_to(
          toggle_label,
          @form_action.merge(action: :reuse, all_users: @all_users ? 0 : 1),
          class: "btn btn-default"
        )
      end
    end

    def toggle_label
      @all_users ? :image_reuse_just_yours.t : :image_reuse_all_users.t
    end

    def render_image_matrix
      paginated_results do
        render(::Components::MatrixTable.new) do
          @objects.each { |image| render_image_card(image) }
        end
      end
    end

    def render_image_card(image)
      render(::Components::MatrixBox.new(
               extra_class: "text-center", id: image.id
             )) do
        render(::Components::Panel.new) do |panel|
          panel.with_body do
            render(::Components::InteractiveImage.new(
                     user: @user,
                     image: image,
                     votes: false,
                     original: true,
                     image_link: @form_action.merge(img_id: image.id),
                     link_method: :post,
                     extra_classes: "image-to-reuse"
                   ))
          end
        end
      end
    end
  end
end
