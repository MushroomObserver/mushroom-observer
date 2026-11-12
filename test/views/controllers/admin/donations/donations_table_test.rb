# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Admin::Donations
  class DonationsTableTest < ComponentTestCase
    def setup
      super
      @donations = Donation.order(created_at: :desc).limit(3).to_a
    end

    def test_renders_table_columns
      html = render_table

      assert_html(html, "table.table")
      # Pull all td texts in the table and check each donation's id +
      # amount appears in some cell (assert_html's at_css would only
      # check the first td).
      td_texts = Nokogiri::HTML(html).css("table.table td").map(&:text)
      @donations.each do |d|
        assert(td_texts.any? { |t| t.include?(d.id.to_s) },
               "Expected a td containing donation id #{d.id}")
        assert(td_texts.any? { |t| t.include?(d.amount.to_s) },
               "Expected a td containing donation amount #{d.amount}")
      end
    end

    def test_renders_reviewed_toggle_per_row
      html = render_table

      @donations.each do |donation|
        # Each row's "Reviewed" cell is a separate form, not one
        # shared table-wide form -- a <form> can't nest inside
        # another one.
        assert_html(html, "form[id='donation_reviewed_#{donation.id}']" \
                          "[action='/admin/donations']")
        assert_html(
          html,
          "form#donation_reviewed_#{donation.id} " \
          "input[name='reviewed[#{donation.id}]'][type='checkbox']" \
          "[data-reviewed-toggle-target='toggle']"
        )
      end
    end

    private

    def render_table
      render(DonationsTable.new(donations: @donations))
    end
  end
end
