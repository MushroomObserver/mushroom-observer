# frozen_string_literal: true

# Action-nav for the edit-location form. Index + cancel-to-show +
# optional external-search-for-this-name links.
class Tab::Location::FormEdit < Tab::Collection
  def initialize(location:)
    super()
    @location = location
  end

  private

  def tabs
    [
      Tab::Location::Index.new,
      Tab::Object::Return.new(object: @location),
      *external_search_tabs
    ].compact
  end

  def external_search_tabs
    return [] unless @location&.name

    Tab::Location::ExternalSearch.new(name: @location.name).to_a
  end
end
