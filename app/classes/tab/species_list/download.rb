# frozen_string_literal: true

class Tab::SpeciesList::Download < Tab::Base
  def initialize(list:, q_param: nil)
    super()
    @list = list
    @q_param = q_param
  end

  def title
    :species_list_show_download.t
  end

  def path
    with_q_param(new_download_species_list_path(@list.id), @q_param)
  end

  def model
    @list
  end
end
