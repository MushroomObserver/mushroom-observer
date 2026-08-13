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
        render_new_view
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
        render_upload_result_view
      else
        redirect_to(species_list_path(@species_list))
      end
    end

    private

    def render_new_view
      render(
        Views::Controllers::SpeciesLists::Uploads::New.new(
          species_list: @species_list
        )
      )
    end

    # Always re-renders this same URL -- no redirect, no real
    # success/failure distinction (upload errors surface as sorter
    # feedback on the same rendered page). Turbo Drive hangs on a
    # same-URL plain-200 response to a Turbo-enabled form regardless
    # of REST semantics (see turbo_submit_forms.md), so
    # :unprocessable_content is required here purely as a Turbo-
    # mechanics necessity, not a statement that the upload "failed".
    def render_upload_result_view
      render(Views::Controllers::SpeciesLists::Edit.new(
               species_list: @species_list,
               projects: @projects,
               dubious_where_reasons: [],
               submitted_project_ids: nil,
               user: @user
             ), status: :unprocessable_content)
    end

    ############################################################################

    include SpeciesLists::SharedPrivateMethods # shared private methods
  end
end
