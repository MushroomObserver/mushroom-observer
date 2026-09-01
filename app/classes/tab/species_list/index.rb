# frozen_string_literal: true

# "Cancel to species list index" action-nav link.
class Tab::SpeciesList::Index < Tab::Base
  def initialize(index_filter: nil)
    super()
    @index_filter = index_filter
  end

  def title
    :cancel_to_index.t(type: :species_list)
  end

  def path
    with_index_filter(species_lists_path, @index_filter)
  end
end
