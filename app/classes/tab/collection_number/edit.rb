# frozen_string_literal: true

# "Edit collection number" link. `back` controls the redirect target
# after editing — `obs.id` to return to a specific observation,
# `:index` to return to the collection_numbers index (pass
# `from_index: true`), `:show` to return to the collection_number
# show page (the default when neither is given).
class Tab::CollectionNumber::Edit < Tab::Base
  def initialize(collection_number:, observation: nil, from_index: false)
    super()
    @collection_number = collection_number
    @observation = observation
    @from_index = from_index
  end

  def title
    :edit_collection_number.l
  end

  def path
    edit_collection_number_path(id: @collection_number.id, back: back)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @collection_number
  end

  private

  def back
    return @observation.id if @observation
    return :index if @from_index

    :show
  end
end
