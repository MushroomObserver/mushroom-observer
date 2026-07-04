# frozen_string_literal: true

# "Reuse an existing image" page rendered by the `reuse` action of
# `Observations::ImagesController`, `Account::Profile::ImagesController`,
# and `GlossaryTerms::ImagesController`.
#
# Two parts:
# - `Components::Image::ReuseForm` — the small form that takes an Image
#   id and POSTs to `<target_domain>/images#attach`.
# - A `paginated_results`-wrapped `Components::Matrix::Table` of
#   clickable thumbnails (each wrapping `Components::Image::Interactive`
#   in a POST link to `attach` so a click attaches that image
#   directly).
#
# The `target` is the domain object (Observation / User /
# GlossaryTerm) whose images are being selected for. Each caller
# passes its subject; the Component derives both the form's submit
# URL and the per-thumbnail POST URL from the target's class.
module Views::Controllers::Shared
  class ImagesToReuseForm < Views::Base
    prop :target,
         _Union(::Observation, ::User, ::GlossaryTerm)
    prop :user, _Nilable(::User), default: nil
    prop :objects, _Array(::Image)
    prop :pagination_data, ::PaginationData
    prop :all_users, _Boolean, default: false

    def view_template
      render(::Components::Image::ReuseForm.new(
               target: @target, all_users: @all_users
             ))
      render_image_matrix
    end

    private

    def render_image_matrix
      PaginatedResults do
        render(::Components::Matrix::Table.new) do
          @objects.each { |image| render_image_card(image) }
        end
      end
    end

    def render_image_card(image)
      render(::Components::Matrix::Box.new(
               extra_class: "text-center", id: image.id
             )) do
        render(::Components::Panel.new) do |panel|
          panel.with_body do
            render(::Components::Image::Interactive.new(
                     user: @user,
                     image: image,
                     votes: false,
                     original: true,
                     image_link: attach_url_for(image),
                     link_method: :post,
                     extra_classes: "image-to-reuse"
                   ))
          end
        end
      end
    end

    def attach_url_for(image)
      url_for(controller: target_controller,
              action: :attach, id: @target.id, img_id: image.id)
    end

    def target_controller
      ::Components::Image::ReuseForm::CONTROLLERS.fetch(@target.class)
    end
  end
end
