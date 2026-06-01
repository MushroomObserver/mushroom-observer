# frozen_string_literal: true

# "Back to collection_numbers index" link (used by the edit form
# when arriving from the index). Carries the current Query through.
class Tab::CollectionNumber::BackToIndex < Tab::Base
  def initialize(collection_number:, q_param: nil)
    super()
    @collection_number = collection_number
    @q_param = q_param
  end

  def title
    :edit_collection_number_back_to_index.l
  end

  def path
    args = @collection_number.index_link_args
    @q_param ? args.merge(q: @q_param) : args
  end

  def model
    @collection_number
  end
end
