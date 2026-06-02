# frozen_string_literal: true

# Action-nav for the contributors index page.
class Tab::Contributor::IndexActions < Tab::Collection
  private

  def tabs
    [Tab::Info::SiteStats.new]
  end
end
