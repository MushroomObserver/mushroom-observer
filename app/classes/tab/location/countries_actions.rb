# frozen_string_literal: true

# Action-nav for the location-countries index page.
class Tab::Location::CountriesActions < Tab::Collection
  private

  def tabs
    [Tab::Location::Index.new]
  end
end
