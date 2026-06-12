# frozen_string_literal: true

# Action-nav for the governance page and the donate/donors thanks +
# wrapup pages.
class Tab::Support::GovernanceActions < Tab::Collection
  private

  def tabs
    [Tab::Support::Donate.new,
     Tab::Support::Donors.new]
  end
end
