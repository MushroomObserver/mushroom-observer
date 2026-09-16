# frozen_string_literal: true

# "Back to collection_numbers index" link (used by the edit form
# when arriving from the index). Carries the current Query through.
class Tab::CollectionNumber::BackToIndex < Tab::Base
  def initialize(collection_number:, index_filter: nil)
    super()
    @collection_number = collection_number
    @index_filter = index_filter
  end

  def title
    :edit_collection_number_back_to_index.l
  end

  def path
    args = @collection_number.index_link_args
    @index_filter ? args.merge(@index_filter) : args
  end

  def model
    @collection_number
  end
end
