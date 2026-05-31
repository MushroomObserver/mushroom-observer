# frozen_string_literal: true

class Tab::SpeciesList::Upload < Tab::Base
  def initialize(list:)
    super()
    @list = list
  end

  def title
    :species_list_upload_title.t
  end

  def path
    new_upload_species_list_path(@list.id)
  end

  def model
    @list
  end
end
