# frozen_string_literal: true

# View Helpers for Projects, Project Violations
module SpeciesListsHelper
  def species_list_title_panel(list)
    tag.div(class: "species_list_title") do
      concat(tag.br)
      concat(panel_block(id: "species_list_title") do
               tag.span(class: "h3") do
                 :species_list_show_title.t(name: list.unique_format_name)
               end
             end)
    end
  end
end
