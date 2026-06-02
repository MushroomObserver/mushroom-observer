# frozen_string_literal: true

# Action-nav for the publications index page.
class Tab::Publication::IndexActions < Tab::Collection
  private

  def tabs
    [Tab::Publication::New.new]
  end
end
