# frozen_string_literal: true

require "test_helper"

module Components
  module Descriptions
    class PermissionsFormTest < ComponentTestCase
      def setup
        super
        @description = name_descriptions(:draft_coprinus_comatus)
        @groups = gather_groups(@description)
      end

      def test_name_description_form_structure
        html = render_form

        # Form structure
        assert_html(html, "form#description_permissions_form")
        assert_html(html, "form[action*='/names/descriptions/']")
        assert_html(html, "form[action*='/permissions']")

        # Two submit buttons (top and bottom)
        assert_equal(2, html.scan(/type=['"]submit['"]/).count)

        # Table structure
        assert_html(html, "table.table-description-permissions")
        assert_html(html, "thead")
        assert_html(html, "tbody")

        # Table headers
        assert_includes(html, :adjust_permissions_user_header.t)
        assert_includes(html, :adjust_permissions_reader_header.t)
        assert_includes(html, :adjust_permissions_writer_header.t)
        assert_includes(html, :adjust_permissions_admin_header.t)
      end

      def test_group_checkboxes
        html = render_form

        # Should have checkbox arrays for group permissions
        assert_html(html,
                    "input[type='checkbox']" \
                    "[name='description_permissions[group_reader][]']")
        assert_html(html,
                    "input[type='checkbox']" \
                    "[name='description_permissions[group_writer][]']")
        assert_html(html,
                    "input[type='checkbox']" \
                    "[name='description_permissions[group_admin][]']")
      end

      def test_writein_fields
        html = render_form

        # 6 writein rows
        (1..6).each do |i|
          # User autocompleter
          assert_html(html,
                      "input[name='description_permissions" \
                      "[writein_name_#{i}]']")
          assert_html(html, "[data-controller='autocompleter--user']")

          # Permission checkboxes for each writein
          assert_html(html,
                      "input[type='checkbox']" \
                      "[name='description_permissions[writein_reader_#{i}]']")
          assert_html(html,
                      "input[type='checkbox']" \
                      "[name='description_permissions[writein_writer_#{i}]']")
          assert_html(html,
                      "input[type='checkbox']" \
                      "[name='description_permissions[writein_admin_#{i}]']")
        end
      end

      def test_group_names_display
        html = render_form

        # Standard group names should be translated
        assert_includes(html, :adjust_permissions_all_users.t)
        assert_includes(html, :REVIEWERS.t)
      end

      # Location descriptions don't have permissions routes - skip this test

      def test_with_writein_data_populated
        data = {
          1 => { name: "katrina", reader: true, writer: false, admin: false }
        }
        html = render_form(@description, @groups, data)

        # The writein name field should have the value
        assert_html(html,
                    "input[name='description_permissions[writein_name_1]']" \
                    "[value='katrina']")
      end

      private

      def render_form(description = @description, groups = @groups, data = nil)
        render(Components::Descriptions::PermissionsForm.new(
                 description: description,
                 groups: groups,
                 data: data
               ))
      end

      def gather_groups(description)
        # Replicate the controller's gather_list_of_groups logic
        (
          [UserGroup.all_users] +
          description.admin_groups.sort_by(&:name) +
          description.writer_groups.sort_by(&:name) +
          description.reader_groups.sort_by(&:name) +
          [UserGroup.reviewers]
        ) + (
          [description.user] +
          description.authors.sort_by(&:login) +
          description.editors.sort_by(&:login)
        ).compact.map { |user| UserGroup.one_user(user) }
      end
    end
  end
end
