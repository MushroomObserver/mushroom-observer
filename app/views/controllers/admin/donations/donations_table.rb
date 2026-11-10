# frozen_string_literal: true

module Views::Controllers::Admin::Donations
  # Table of donations for the admin review page. Each row's
  # "Reviewed" cell is a small self-submitting form (`ReviewToggle`)
  # -- not wrapped in a page-level form, since a `<form>` can't nest
  # inside another `<form>`.
  class DonationsTable < Views::Base
    prop :donations, _Array(::Donation)

    def view_template
      render_donations_table
    end

    private

    def render_donations_table
      Table(
        @donations,
        variant: :striped, align_middle: true,
        class: "table-review-donations"
      ) do |t|
        define_columns(t)
      end
    end

    def define_columns(tbl)
      tbl.column(:id.t) do |d|
        IDBadge(value: d.id, size: :lg)
      end
      tbl.column(:reviewed.ti) do |donation|
        render(ReviewToggle.new(donation: donation))
      end
      define_donor_columns(tbl)
      define_detail_columns(tbl)
    end

    def define_donor_columns(tbl)
      tbl.column(:who.ti) do |d|
        d.who.to_s.truncate(30)
      end
      tbl.column(:review_anon.t) { |d| d.anonymous.to_s }
    end

    def define_detail_columns(tbl)
      tbl.column(:review_amount.t) { |d| d.amount.to_s }
      tbl.column(:email.ti) do |d|
        d.email.to_s.truncate(50)
      end
      tbl.column(:date.ti) do |d|
        d.created_at.strftime("%Y-%m-%d")
      end
    end
  end
end
