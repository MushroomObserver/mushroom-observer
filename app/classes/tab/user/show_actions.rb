# frozen_string_literal: true

# Action-nav for the user show page. Just the contributors index
# link.
class Tab::User::ShowActions < Tab::Collection
  private

  def tabs
    [Tab::Contributor::Index.new]
  end
end
