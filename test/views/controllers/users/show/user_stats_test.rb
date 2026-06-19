# frozen_string_literal: true

require "test_helper"

module Views::Controllers::Users
  class Show
    class UserStatsTest < ComponentTestCase
      def setup
        super
        @user = users(:rolf)
        controller.instance_variable_set(:@user, @user)
      end

      # Exercises every render branch:
      # - count-row WITH url → `render_link_or_label` link_to branch
      # - count-row WITHOUT url → `render_link_or_label` plain-label branch
      # - count-row with weight set → `count_text` weight branch
      # - row with nil count + SafeBuffer label (the languages summary
      #   row in `UserStatsHelper`) → `render_no_count_row` + the
      #   `render_label` SafeBuffer branch
      # - row with nil count + plain text label (a bonus row)
      # - non-zero total → `render_total_rows`
      def test_renders_all_row_shapes
        rows = [
          { field: :observations, label: "Observations", count: 5,
            weight: 1, points: 5 },
          { field: :unlinked, label: "Unlinked Field", count: 3,
            weight: nil, points: 3 },
          { label: ::ActiveSupport::SafeBuffer.new("<span>EN: 4</span>"),
            count: nil, points: 0 },
          { label: "Bonus reason", count: nil, points: 10 }
        ]
        html = render(UserStats.new(show_user: @user, name: @user.login,
                                    rows: rows))
        link_path = routes.observations_path(by_user: @user.id)
        assert_html(html, "tr td a[href='#{link_path}']")
        assert_includes(html, "Unlinked Field")
        assert_html(html, "tr td span", text: "EN: 4")
        assert_includes(html, "Bonus reason")
        # Total row appears with sum of all points (5+3+0+10 = 18).
        assert_includes(html, "18")
      end

      def test_renders_no_total_when_zero
        rows = [
          { field: :observations, label: "Observations", count: 0,
            weight: 1, points: 0 }
        ]
        html = render(UserStats.new(show_user: @user, name: @user.login,
                                    rows: rows))
        # Empty body still has the panel header but no hr/total tr.
        assert_no_html(html, "tr td hr")
      end
    end
  end
end
