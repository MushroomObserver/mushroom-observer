# frozen_string_literal: true

# Controls viewing and modifying herbaria.
module Herbaria
  class SearchesController < ApplicationController
    # filters

    # Old MO Action (method)        New "Normalized" Action (method)
    # ----------------------        --------------------------------
    # herbarium_search (get)        Herbaria::Searches#index (get)

    # ---------- Actions to Display data (index, show, etc.) ---------------------

    # list of Herbaria whose text matches a string pattern.
    def index
      pattern = params[:pattern].to_s
      if pattern.match(/^\d+$/) && (herbarium = Herbarium.safe_find(pattern))
        redirect_to(herbarium_path(herbarium.id))
      else
        query = create_query(:Herbarium, :pattern_search, pattern: pattern)
        show_selected_herbaria(query)
      end
    end

    ##############################################################################

    private

    include Herbaria::SharedPrivateMethods

    def show_selected_herbaria(query, args = {})
      args = show_index_args(args)

      # Clean up display by removing user-related stuff from nonpersonal index.
      if query.flavor == :nonpersonal
        args[:sorting_links].reject! { |x| x[0] == "user" }
        @no_user_column = true
      end

      # If user clicks "merge" on an herbarium, it reloads the page and asks
      # them to click on the destination herbarium to merge it with.
      @merge = Herbarium.safe_find(params[:merge])
      @links = right_tab_links(query, @links)
      show_index_of_objects(query, args)
    end

    def right_tab_links(query, links)
      links ||= []
      unless query.flavor == :all
        links << [:herbarium_index_list_all_herbaria.l, herbaria_path]
      end
      unless query.flavor == :nonpersonal
        links << [:herbarium_index_nonpersonal_herbaria.l,
                  nonpersonal_herbaria_path]
      end
      links << [:create_herbarium.l, herbaria_path(method: :post)]
    end

    def show_index_args(args)
      { # default args
        letters: "herbaria.name",
        num_per_page: 100,
        include: [:curators, :herbarium_records, :personal_user]
      }.merge(args,
              template: "/herbaria/index.html.erb", # render with this template
              sorting_links: [ # Add some alternate sorting criteria.
                ["records",     :sort_by_records.t],
                ["user",        :sort_by_user.t],
                ["code",        :sort_by_code.t],
                ["name",        :sort_by_name.t],
                ["created_at",  :sort_by_created_at.t],
                ["updated_at",  :sort_by_updated_at.t]
              ])
    end
  end
end
