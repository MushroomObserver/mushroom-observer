# frozen_string_literal: true

# Action-nav for the new-location form. Index link + optional
# external-search-for-this-name links when a `location.name` is
# present (typically set when the form was reached from an
# observation submission with a typed-but-unknown location).
class Tab::Location::FormNew < Tab::Collection
  def initialize(location:)
    super()
    @location = location
  end

  private

  def tabs
    [Tab::Location::Index.new, *external_search_tabs].compact
  end

  def external_search_tabs
    return [] unless @location&.name

    Tab::Location::ExternalSearch.new(name: @location.name).to_a
  end
end
