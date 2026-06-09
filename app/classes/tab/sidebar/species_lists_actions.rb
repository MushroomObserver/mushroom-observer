# frozen_string_literal: true

# Sidebar "Species Lists" section. Caller renders this only when a
# user is logged in (per Sidebar's `return unless @user`
# guard); the Collection still handles `user: nil` defensively by
# omitting the user-only tabs.
class Tab::Sidebar::SpeciesListsActions < Tab::Collection
  def initialize(user: nil)
    super()
    @user = user
  end

  private

  def tabs
    return [Tab::Sidebar::SpeciesLists::All.new] unless @user

    [Tab::Sidebar::SpeciesLists::Yours.new(user: @user),
     Tab::Sidebar::SpeciesLists::All.new,
     Tab::Sidebar::SpeciesLists::New.new]
  end
end
