# frozen_string_literal: true

# "Delete collection number" button-tab.
class Tab::CollectionNumber::Destroy < Tab::Base
  def initialize(collection_number:)
    super()
    @collection_number = collection_number
  end

  def title
    :delete_collection_number.l
  end

  def path
    @collection_number
  end

  def html_options
    { button: :destroy, icon: :delete }
  end

  def model
    @collection_number
  end
end
