# frozen_string_literal: true

# One donation's "Reviewed" checkbox, as a small form that submits on
# change -- same `reviewed-toggle` Stimulus controller as
# `ObservationFragment::MarkAsReviewedToggle`. Rendered once per row
# by `Table`, inside the "Reviewed" column's cell.
module Views::Controllers::Admin::Donations
  class ReviewToggle < ::Components::ApplicationForm
    prop :donation, ::Donation

    def initialize(donation:)
      super(::FormObject::ReviewDonations.new,
            donation: donation,
            id: "donation_reviewed_#{donation.id}",
            method: :patch,
            data: { controller: "reviewed-toggle" })
    end

    def view_template
      super do
        checkbox_field(
          "reviewed[#{@donation.id}]",
          checked: @donation.reviewed,
          label: @donation.reviewed ? :reviewed.ti : false,
          wrap_class: "my-0",
          data: { reviewed_toggle_target: "toggle",
                  action: "reviewed-toggle#submitForm" }
        )
      end
    end

    def form_action
      admin_donations_path
    end
  end
end
