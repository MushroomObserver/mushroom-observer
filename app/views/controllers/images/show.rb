# frozen_string_literal: true

module Views::Controllers::Images
  # Image show page: two-column layout — image + license-history
  # panels on the left, info + (reviewer-only) export controls +
  # vote panel on the right, followed by the copyright /
  # license-badge + versions-footer row. Converted from
  # `images/show.html.erb` + four `show/_*` partials.
  class Show < Views::Base
    # `export_status_controls` / `export_status_ml_controls` compose
    # `link_with_query` + `tag.b` + safe_join; per the conversion
    # rules they stay registered (multi-helper bodies).
    register_output_helper :export_status_controls, mark_safe: true
    register_output_helper :export_status_ml_controls, mark_safe: true

    prop :image, ::Image
    # `ImagesController#set_default_size` normalizes `@size` to a
    # Symbol (`params[:size].to_sym` or `@user.image_size`), but
    # `Observations::ImagesController#update` re-renders this view
    # without setting size (defaulting to nil) and some test paths
    # pass a String straight through. `_Union(Symbol, String)`
    # accepts both shapes — comparisons in `VotePanel#vote_link_args`
    # don't care.
    prop :size, _Nilable(_Union(::Symbol, ::String)), default: nil
    prop :default_size, _Nilable(_Union(::Symbol, ::String)), default: nil

    def view_template
      add_show_title(@image)
      add_pager_for(@image)
      add_context_nav(::Tab::Image::ShowActions.new(
                        image: @image, permission: permission?(@image)
                      ))
      container_class(:full)
      column_classes(:six)

      render_main_row
      render_footer_row
    end

    private

    def render_main_row
      div(class: "row") do
        div(class: content_for(:left_columns).to_s) { render_left_column }
        div(class: content_for(:right_columns).to_s) { render_right_column }
      end
    end

    def render_left_column
      render(ImagePanel.new(image: @image, size: @size))
      render(LicenseHistoryPanel.new(image: @image))
    end

    def render_right_column
      render(InfoPanel.new(image: @image))
      render_reviewer_export_controls if reviewer?
      div(id: "image_votes_container") do
        render(VotePanel.new(image: @image,
                             size: @size, default_size: @default_size))
      end
    end

    def render_reviewer_export_controls
      div(class: "mb-5 text-center") do
        p { export_status_controls(@image) }
        p { export_status_ml_controls(@image) }
      end
    end

    def render_footer_row
      div(class: "row") do
        div(class: content_for(:left_columns).to_s) { render_left_footer }
        div(class: content_for(:right_columns).to_s) { render_right_footer }
      end
    end

    def render_left_footer
      div(class: "small text-center") do
        div do
          render(::Components::ImageCopyright.new(
                   user: current_user, image: @image
                 ))
        end
        div(class: "py-5px mb-3") do
          render(::Components::LicenseBadge.new(license: @image.license))
        end
      end
    end

    def render_right_footer
      render(::Components::VersionsFooter.new(user: current_user, obj: @image))
    end
  end
end
