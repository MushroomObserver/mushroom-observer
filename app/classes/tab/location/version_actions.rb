# frozen_string_literal: true

# Action-nav for the location versions page.
class Tab::Location::VersionActions < Tab::Collection
  def initialize(location:)
    super()
    @location = location
  end

  private

  def tabs
    [Tab::Location::Versions.new(location: @location)]
  end
end
