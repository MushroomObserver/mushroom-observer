# frozen_string_literal: true

module Views::Controllers::Admin::Donations
  # New-donation page. Delegates the body to `Form`; this wrapper
  # sets the page title and context nav.
  class New < Views::Base
    prop :donation, ::Donation

    def view_template
      add_page_title(:create_donation_title.l)
      add_context_nav(::Tab::Admin::DonationsFormNew.new)
      render(Form.new(@donation))
    end
  end
end
