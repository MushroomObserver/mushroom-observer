# frozen_string_literal: true

# Image-matrix grid for a visual group's edit + show pages. Every
# image in the current subset gets its own matrix box with the
# image's panel + a `StatusLinks` block (needs-review / include /
# exclude trio + image id link).
module Views::Controllers::VisualGroups
  class ImageMatrix < Views::Base
    prop :user, _Nilable(User)
    prop :visual_group, VisualGroup
    prop :subset, _Array(_Tuple(::Image, _Nilable(_Boolean)))
    prop :status, String
    prop :pagination_data, _Nilable(PaginationData)

    def view_template
      PaginatedResults do
        render(Components::Matrix::Table.new) do
          @subset.each { |row| render_matrix_box(row) }
        end
      end
    end

    private

    def render_matrix_box(row)
      image, image_status = row
      render(Components::Matrix::Box.new(id: image.id)) do
        Panel do |panel|
          panel.with_thumbnail do
            InteractiveImage(
              user: @user, image: image, original: true,
              votes: false, full_width: true
            )
          end
          panel.with_body do
            render(StatusLinks.new(
                     visual_group: @visual_group,
                     image_id: image.id,
                     status: image_status
                   ))
          end
        end
      end
    end
  end
end
