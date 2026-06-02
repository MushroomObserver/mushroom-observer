# frozen_string_literal: true

# Action-nav for the licenses index page.
class Tab::License::IndexActions < Tab::Collection
  private

  def tabs
    [Tab::License::New.new]
  end
end
