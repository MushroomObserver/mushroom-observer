# frozen_string_literal: true

# Custom Tabset Helpers for Herbaria views
#
module Tabs
  module HerbariaHelper
    def herbaria_index_tabs(query)
      links ||= []
      unless query&.flavor == :all
        links << [:herbarium_index_list_all_herbaria.l,
                  herbaria_path(flavor: :all), { id: "all_herbaria_link" }]
      end
      unless query&.flavor == :nonpersonal
        links << [:herbarium_index_nonpersonal_herbaria.l,
                  herbaria_path(flavor: :nonpersonal),
                  { id: "all_nonpersonal_herbaria_link" }]
      end
      links << [:create_herbarium.l, new_herbarium_path,
                { id: "new_herbarium_link" }]
    end
  end
end
