# frozen_string_literal: true

# Action-nav for the new species_list form: Name Lister + cancel
# to index.
class Tab::SpeciesList::FormNew < Tab::Collection
  def initialize(index_filter: nil)
    super()
    @index_filter = index_filter
  end

  private

  def tabs
    [
      Tab::SpeciesList::NameLister.new,
      Tab::SpeciesList::Index.new(index_filter: @index_filter)
    ]
  end
end
