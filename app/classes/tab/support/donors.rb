# frozen_string_literal: true

# "Donors" page link.
class Tab::Support::Donors < Tab::Base
  def title
    :donors_tab.t
  end

  def path
    support_donors_path
  end
end
