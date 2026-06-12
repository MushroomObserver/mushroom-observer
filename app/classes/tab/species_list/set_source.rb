# frozen_string_literal: true

class Tab::SpeciesList::SetSource < Tab::Base
  def initialize(list:, q_param: nil)
    super()
    @list = list
    @q_param = q_param
  end

  def title
    :species_list_show_set_source.t
  end

  def path
    with_q_param(species_list_path(@list.id, set_source: 1), @q_param)
  end

  def html_options
    { help: :species_list_show_set_source_help.l }
  end

  def model
    @list
  end
end
