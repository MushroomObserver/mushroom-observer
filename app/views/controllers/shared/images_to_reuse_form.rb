# frozen_string_literal: true

# "Reuse an existing image" page rendered by the `reuse` action of
# `Observations::ImagesController`, `Account::Profile::ImagesController`,
# and `GlossaryTerms::ImagesController`. Replaces the
# `app/views/controllers/shared/_images_to_reuse.erb` partial.
#
# Two parts:
# - `Components::ImageReuseForm` — the small form that takes an Image
#   id and POSTs to `form_action[:controller]#attach`.
# - A `paginated_results`-wrapped `Components::MatrixTable` of
#   clickable thumbnails (each wrapping `Components::InteractiveImage`
#   in a POST link to `attach` so a click attaches that image
#   directly).
#
# Data (the paginated `objects:` and `pagination_data:`) is loaded by
# the controller via `ImageReusable#load_images_to_reuse` — this
# view does not query.
module Views::Controllers::Shared
  class ImagesToReuseForm < Views::Base
    prop :form_action, Hash
    prop :user, _Nilable(::User), default: nil
    prop :objects, _Array(::Image)
    prop :pagination_data, ::PaginationData
    prop :all_users, _Boolean, default: false

    def view_template
      render(::Components::ImageReuseForm.new(
               form_action: @form_action, all_users: @all_users
             ))
      render_image_matrix
    end

    private

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
