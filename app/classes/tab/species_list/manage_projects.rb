# frozen_string_literal: true

class Tab::SpeciesList::ManageProjects < Tab::Base
  def initialize(list:)
    super()
    @list = list
  end

  def title
    :species_list_show_manage_projects.t
  end

  def path
    edit_projects_for_species_list_path(@list.id)
  end

  def html_options
    { help: :species_list_show_manage_projects_help.l }
  end

  def model
    @list
  end
end
