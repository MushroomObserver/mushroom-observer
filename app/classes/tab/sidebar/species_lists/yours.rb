# frozen_string_literal: true

# Sidebar species_lists nav: your lists filter. User-only.
class Tab::Sidebar::SpeciesLists::Yours < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :app_your_lists.t
  end

  def path
    species_lists_path(by_user: @user.id)
  end

  def html_options
    { id: "nav_your_species_lists_link" }
  end
end
