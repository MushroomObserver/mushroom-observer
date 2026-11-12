# frozen_string_literal: true

require "test_helper"

module Views::Controllers::Locations::Descriptions::Moves
  class FormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @description = location_descriptions(:albion_desc)
    end

    def test_form_renders_location_autocompleter
      html = render_form(@description)

      # Form structure
      assert_html(html, "form#move_descriptions_form")
      assert_html(html, "form[method='post']")
      assert_html(html, "form[action*='/locations/descriptions/']")
      assert_html(html, "form[action*='/moves']")

      # Header and help text
      assert_includes(html, :merge_descriptions_move_location_header.t)
      assert_includes(html, :merge_descriptions_move_location_help.t)

      # Location autocompleter: visible text field + hidden id field,
      # the id field is the one check_dest_exists! reads.
      assert_html(html,
                  "input[name='description_move_or_merge[target]']")
      assert_html(html,
                  "input[type='hidden']" \
                  "[name='description_move_or_merge[target_id]']")

      # Delete checkbox
      assert_html(html, "input[type='checkbox']" \
                        "[name='description_move_or_merge[delete]']")
      assert_includes(html, :merge_descriptions_delete_after.t)

      # Submit button
      assert_html(html, "button[type='submit']", text: :submit.ti)
    end

    private

    def render_form(description)
      render(Form.new(description, user: @user))
    end
  end
end
