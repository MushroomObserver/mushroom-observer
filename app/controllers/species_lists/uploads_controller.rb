# frozen_string_literal: true

module SpeciesLists
  class UploadsController < ApplicationController
    before_action :login_required

    # Form to let user add to a species_list from file.
    def new
      return unless (@species_list = find_species_list!)

      if permission!(@species_list)
        query = create_query(:Observation, species_lists: @species_list,
                                           order_by: :name)
        @observation_list = query.results
        render(
          Views::Controllers::SpeciesLists::Uploads::New.new(
            species_list: @species_list
          ),
          layout: true
        )
      else
        redirect_to(species_list_path(@species_list))
      end
    end

    # Upload form posts here
    def create
      return unless (@species_list = find_species_list!)

      if permission!(@species_list)
        sorter = NameSorter.new
        @species_list.file = params[:species_list][:file]
        @species_list.process_file_data(@user, sorter)
        init_name_vars_from_sorter(@species_list, sorter)
        init_project_vars_for_edit(@species_list)
        # `species_lists/edit.html.erb` is now Phlex (see #4389) — render
        # the class directly. No form re-render path here, so the
        # dubious-where / submitted-project ivars stay empty.
        render(Views::Controllers::SpeciesLists::Edit.new(
                 species_list: @species_list,
                 projects: @projects,
                 dubious_where_reasons: [],
                 submitted_project_ids: nil,
                 user: @user
               ))
      else
        redirect_to(species_list_path(@species_list))
      end
    end

    ############################################################################

    include SpeciesLists::SharedPrivateMethods # shared private methods
  end
end
