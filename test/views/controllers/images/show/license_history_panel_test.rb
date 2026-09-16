# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images
  class Show
    class LicenseHistoryPanelTest < ComponentTestCase
      def setup
        super
        @image = images(:in_situ_image)
        controller.instance_variable_set(:@user, users(:rolf))
      end

      def test_renders_nothing_without_copyright_changes
        html = render_panel

        assert_equal("", html)
      end

      def test_renders_history_rows_and_current_row
        old_change = CopyrightChange.create!(
          user: users(:rolf), target: @image,
          updated_at: 1.year.ago, license: licenses(:ccby),
          year: 2018, name: "Old Holder"
        )
        newer_change = CopyrightChange.create!(
          user: users(:rolf), target: @image,
          updated_at: 1.month.ago, license: licenses(:ccbync),
          year: 2019, name: "Newer Holder"
        )
        assert_operator(old_change.id, :<, newer_change.id,
                        "Test needs old_change created before newer_change")

        html = render_panel
        doc = Nokogiri::HTML.fragment(html)

        assert_html(html, "table.table-license-history")
        # 2 CopyrightChange rows + 1 "current" row
        assert_html(html, "table.table-license-history tbody tr", count: 3)
        cell_text = doc.css("table.table-license-history td").map(&:text)
        assert(cell_text.any? { |t| t.include?("Old Holder") },
               "Expected a cell containing 'Old Holder', got: #{cell_text}")
        assert(cell_text.any? { |t| t.include?("Newer Holder") },
               "Expected a cell containing 'Newer Holder', got: #{cell_text}")
        assert_html(html, "a[href='#{licenses(:ccby).url}']")
        assert_html(html, "a[href='#{licenses(:ccbync).url}']")
        assert_html(html, "a[href='#{@image.license.url}']")
      end

      private

      def render_panel
        render(LicenseHistoryPanel.new(image: @image))
      end
    end
  end
end
