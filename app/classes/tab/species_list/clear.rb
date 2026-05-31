# frozen_string_literal: true

class Tab::SpeciesList::Clear < Tab::Base
  def initialize(list:)
    super()
    @list = list
  end

  def title
    :species_list_show_clear_list.t
  end

  def path
    clear_species_list_path(@list.id)
  end

  def html_options
    { button: :put, class: "text-danger",
      data: { confirm: :are_you_sure.l } }
  end

  def model
    @list
  end
end
