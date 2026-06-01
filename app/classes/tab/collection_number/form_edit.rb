# frozen_string_literal: true

# Action-nav for the collection_number edit form. When the user
# arrived from the index, `back: "index"` and the back-link returns
# to the index (`BackToIndex`); otherwise back to whatever
# `back_object` is (typically the parent Observation).
class Tab::CollectionNumber::FormEdit < Tab::Collection
  def initialize(collection_number:, back:, back_object:, q_param: nil)
    super()
    @collection_number = collection_number
    @back = back
    @back_object = back_object
    @q_param = q_param
  end

  private

  def tabs
    return [back_to_index] if @back == "index"

    [Tab::Object::Return.new(object: @back_object)]
  end

  def back_to_index
    Tab::CollectionNumber::BackToIndex.new(
      collection_number: @collection_number, q_param: @q_param
    )
  end
end
