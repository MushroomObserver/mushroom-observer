# frozen_string_literal: true

require("test_helper")

module Form
  module UploadGallery
    # `Components::Form::UploadGallery::Item` no longer owns the outer
    # `<div class="item carousel-item …">` wrapper — that moved to
    # `Components::Carousel`'s `c.item(...) { … }` registration (see
    # the A-pattern refactor on PR #4560). This test covers what the
    # Item now emits: the `.row` layout with image column, form column
    # (suppressed for siblings), and control buttons.
    class ItemTest < ComponentTestCase
      def setup
        super
        @user = users(:rolf)
        @image = images(:connected_coprinus_comatus_image)
      end

      def test_renders_row_with_image_and_form_columns
        html = render_item

        assert_html(html, "div.row > div.col-12.col-md-6 > " \
                          "div.image-position > img")
        assert_html(html, "div.row > div.col-12.col-md-6 > " \
                          "div.form-panel")
      end

      # Sibling slides (cross-observation thumbnail reuse) suppress the
      # form column AND the remove button so the user can't edit fields
      # that don't belong to this observation.
      def test_sibling_suppresses_form_column_and_remove_button
        html = render_item(sibling: true)

        assert_no_html(html, "div.form-panel")
        assert_no_html(html, ".remove_image_button")
      end

      # Set-as-thumbnail radio (`Components::ApplicationForm::ButtonStyleRadio`)
      # uses the `observation[thumb_image_id]` name so a browser-native
      # radio group across slides submits the picked id.
      def test_renders_set_as_thumbnail_radio
        html = render_item

        assert_html(html, "input[type='radio']" \
                          "[name='observation[thumb_image_id]']" \
                          "[value='#{@image.id}']")
      end

      # `obs_thumb_id` matching the image's id renders the radio as
      # `checked`.
      def test_obs_thumb_id_match_marks_radio_checked
        html = render_item(obs_thumb_id: @image.id)

        assert_html(html, "input[type='radio'][checked]" \
                          "[value='#{@image.id}']")
      end

      private

      def render_item(image: @image, upload: false,
                      obs_thumb_id: nil, sibling: false)
        render(Components::Form::UploadGallery::Item.new(
                 user: @user,
                 image: image,
                 upload: upload,
                 obs_thumb_id: obs_thumb_id,
                 sibling: sibling
               ))
      end
    end
  end
end
