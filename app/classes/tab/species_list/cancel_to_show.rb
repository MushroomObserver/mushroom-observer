# frozen_string_literal: true

# "Cancel and show this list" link — used from forms that edit a
# child of a species_list (write-in form, etc.).
class Tab::SpeciesList::CancelToShow < Tab::Base
  def initialize(list:)
    super()
    @list = list
  end

  def title
    :cancel_and_show.t(TYPE: @list.type_tag)
  end

  def path
    species_list_path(@list.id)
  end

  def model
    @list
  end
end
