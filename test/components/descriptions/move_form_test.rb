# frozen_string_literal: true

require "test_helper"

module Components
  module Descriptions
    class MoveFormTest < ComponentTestCase
      def setup
        super
        @user = users(:rolf)
      end

      def test_name_description_with_synonyms
        # Find a description whose parent has synonyms (non-misspelling)
        desc = NameDescription.all.find do |d|
          syns = d.parent.synonyms - [d.parent]
          syns.reject!(&:is_misspelling?)
          syns.any?
        end
        skip("No description with synonyms found") unless desc

        html = render_form(desc)

        # Form structure
        assert_html(html, "form#move_descriptions_form")
        assert_html(html, "form[method='post']")
        assert_html(html, "form[action*='/names/descriptions/']")
        assert_html(html, "form[action*='/moves']")

        # Header and help text
        assert_includes(html, :merge_descriptions_move_header.t)
        assert_includes(html, :merge_descriptions_move_help.t)

        # Radio buttons for move targets
        assert_html(html,
                    "input[type='radio'][name='description_action[target]']")

        # Delete checkbox
        assert_html(html,
                    "input[type='checkbox'][name='description_action[delete]']")
        assert_includes(html, :merge_descriptions_delete_after.t)

        # Submit button
        assert_html(html, "input[type='submit'][value='#{:SUBMIT.l}']")
      end

      def test_name_description_without_synonyms
        # Use a description whose parent has no synonyms
        desc = name_descriptions(:coprinus_comatus_desc)
        html = render_form(desc)

        # Form renders but is minimal (no move targets)
        assert_html(html, "form#move_descriptions_form")

        # Header still shows
        assert_includes(html, :merge_descriptions_move_header.t)

        # No radio buttons when no synonyms
        assert_not_includes(html, "input[type='radio']")

        # No submit button when nothing to move to
        assert_no_match(/type=['"]submit['"]/, html)
      end

      # MoveForm only makes sense for NameDescriptions since Locations
      # don't have synonyms. Skip location test.

      private

      def render_form(description)
        render(Components::Descriptions::MoveForm.new(description, user: @user))
      end
    end
  end
end
