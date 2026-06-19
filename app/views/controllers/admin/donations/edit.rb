# frozen_string_literal: true

module Views::Controllers::Admin::Donations
  # Review-donations page. Delegates the body to `ReviewForm`; this
  # wrapper sets the page chrome (full-width container, title,
  # context nav).
  class Edit < Views::FullPageBase
    prop :donations, _Array(::Donation)

    def view_template
      container_class(:full)
      add_page_title(:review_donations_title.l)
      add_context_nav(::Tab::Admin::DonationsFormEdit.new)
      render(ReviewForm.new(::FormObject::ReviewDonations.new,
                            donations: @donations))
    end
  end
end
