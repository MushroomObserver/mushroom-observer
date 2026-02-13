# frozen_string_literal: true

# Admin form for reviewing donations.
# Renders a table of donations with checkboxes for marking
# each donation as reviewed.
class Components::DonationsReviewForm < Components::ApplicationForm
  def initialize(form, donations:, **)
    @donations = donations
    super(form, **)
  end

  def view_template
    submit(
      :review_donations_update.l, center: true
    )
    render_donations_table
    submit(
      :review_donations_update.l, center: true
    )
  end

  def form_action
    admin_donations_path
  end

  private

  def form_tag(&block)
    form(
      action: form_action, method: :post,
      **form_attributes, &block
    )
  end

  def form_attributes
    {
      id: "admin_review_donations_form",
      style: "display: contents"
    }
  end

  def render_donations_table
    div(class: "text-center") do
      render(
        Components::Table.new(
          @donations,
          class: "table-striped " \
                 "table-review-donations mb-3 mt-3"
        )
      ) do |t|
        define_columns(t)
      end
    end
  end

  def define_columns(tbl)
    tbl.column(:review_reviewed.t) do |donation|
      render_checkbox(donation)
    end
    define_data_columns(tbl)
  end

  def define_data_columns(tbl)
    tbl.column(:review_id.t) { |d| d.id.to_s }
    tbl.column(:review_who.t, &:who)
    tbl.column(:review_anon.t) { |d| d.anonymous.to_s }
    tbl.column(:review_amount.t) { |d| d.amount.to_s }
    tbl.column(:review_email.t, &:email)
  end

  def render_checkbox(donation)
    input(
      type: "hidden",
      name: "reviewed[#{donation.id}]",
      value: "0",
      autocomplete: "off"
    )
    input(
      type: "checkbox",
      name: "reviewed[#{donation.id}]",
      id: "reviewed_#{donation.id}",
      value: "1",
      checked: donation.reviewed,
      class: "form-control"
    )
  end
end
