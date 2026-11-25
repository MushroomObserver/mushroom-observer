# frozen_string_literal: true

# Image-matrix grid for a visual group's edit + show pages. Each
# grid box holds the image, a `StatusLinks` block (needs-review /
# include / exclude trio), and a filename/id-badge footer row.
module Views::Controllers::VisualGroups
  class ImageMatrix < Views::Base
    prop :user, _Nilable(User)
    prop :visual_group, VisualGroup
    prop :subset, _Array(_Tuple(::Image, _Nilable(_Boolean)))
    prop :status, String
    prop :pagination_data, _Nilable(PaginationData)

    def view_template
      PaginatedResults do
        Grid() do
          @subset.each { |row| render_matrix_box(row) }
        end
      end
    end

    private

    def render_matrix_box(row)
      image, image_status = row
      render(Components::Grid::Box.new(id: image.id)) do
        Panel do |panel|
          panel.with_thumbnail do
            InteractiveImage(
              user: @user, image: image, show_filename_row: false,
              votes: false, full_width: true
            )
          end
          panel.with_body(classes: "py-0") do
            render(StatusLinks.new(
                     visual_group: @visual_group,
                     image: image,
                     status: image_status
                   ))
          end
          panel.with_footer { render_filename_and_badge_row(image) }
        end
      end
    end

    def render_filename_and_badge_row(image)
      div(class: "d-flex justify-content-between align-items-center") do
        render(::Components::Image::OriginalFilenameRow.new(image: image))
        span do
          plain(append_colon(:image_reuse_id.ti))
          Badge(variant: :id, object: image, size: :xl,
                link: image_path(id: image.id))
        end
      end
    end
  end
end
