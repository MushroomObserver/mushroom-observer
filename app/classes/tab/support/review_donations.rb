# frozen_string_literal: true

# "Review donations" admin link.
class Tab::Support::ReviewDonations < Tab::Base
  def title
    :review_donations_tab.t
  end

  def path
    admin_review_donations_path
  end
end
