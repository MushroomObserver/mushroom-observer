# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Observations::Namings::Votes
  class TableTest < ComponentTestCase
    def setup
      super
      @naming = namings(:coprinus_comatus_naming)
    end

    def test_renders_table_with_header_value_rows_and_totals
      html = render(Table.new(naming: @naming))

      assert_html(html, "table.table-naming-votes")
      # Five column headers — five separate `assert_includes` since
      # `assert_html(..., text:)` only inspects the first match.
      assert_includes(html, :show_votes_vote.t)
      assert_includes(html, :show_votes_score.t)
      assert_includes(html, :show_votes_weight.t)
      assert_includes(html, :show_votes_users.t)
      assert_includes(html, :show_votes_total.t)
    end

    # The header's rightmost cell and the totals row's rightmost cell
    # are spacer cells — they hold a single non-breaking space
    # (U+00A0) so the column keeps its width even when empty. A
    # regular space would let some browsers collapse the cell.
    def test_spacer_cells_contain_non_breaking_space
      html = render(Table.new(naming: @naming))
      doc = Nokogiri::HTML(html)

      header_rows = doc.css("table.table-naming-votes tr")
      spacer_th = header_rows.first.css("th").last
      assert(spacer_th, "header spacer <th> must be present")
      # `&nbsp;` decoded by Nokogiri is U+00A0; reject regular
      # whitespace so we don't silently degrade to a collapsible cell.
      assert_equal(" ", spacer_th.text,
                   "header spacer cell must hold U+00A0 (non-breaking " \
                   "space), got #{spacer_th.text.bytes.inspect}")

      totals_td = doc.css("table.table-naming-votes tr").last.css("td").last
      assert_equal(" ", totals_td.text,
                   "totals-row spacer cell must hold U+00A0")
    end

    def test_renders_voter_user_links_for_non_anonymous_votes
      html = render(Table.new(naming: @naming))

      assert_html(html, "table.table-naming-votes a[href*='/users/']")
    end

    # `render_visible_voters` caps at 3 names and emits "..." for the
    # 4th+ voter. Create 4 votes at the same value to force the cap.
    def test_renders_ellipsis_when_more_than_three_visible_voters
      obs = @naming.observation
      val = Vote.next_best_vote
      @naming.votes.destroy_all
      [users(:rolf), users(:mary), users(:katrina), users(:dick)].each do |u|
        Vote.create!(naming: @naming, observation: obs,
                     user: u, value: val, favorite: false)
      end

      html = render(Table.new(naming: @naming.reload))

      assert_html(html, "td small", text: "...")
    end
  end
end
