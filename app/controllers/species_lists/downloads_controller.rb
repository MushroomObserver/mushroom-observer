# frozen_string_literal: true

module SpeciesLists
  class DownloadsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params, except: [:print_labels]

    ############################################################################
    #
    #  :section: Reports
    #
    ############################################################################

    # Template shows three forms: print_labels, make_report, and download obs
    def new
      @list = find_species_list!
      @type = params[:type] || "txt"
      @format = params[:format] || "raw"
      @encoding = params[:encoding] || "UTF-8"
      @query = lookup_species_list_query(@list)
    end

    def create
      @list = find_species_list!
      @type = params[:type] || "txt"
      @format = params[:format] || "raw"
      @encoding = params[:encoding] || "UTF-8"
      @query = lookup_species_list_query(@list)

      make_report
    end

    # This endpoint just redirects to Observations::Downloads#print_labels
    def print_labels
      species_list = find_species_list!
      query = lookup_species_list_query(species_list)
      redirect_with_query(print_labels_for_observations_path, query)
    end

    private

    def lookup_species_list_query(list)
      Query.lookup_and_save(:Observation, :in_species_list,
                            species_list: list)
    end

    # Used by download.
    def make_report
      return unless (@species_list = find_species_list!)

      names = @species_list.names
      case params[:type]
      when "txt"
        render_name_list_as_txt(names)
      when "rtf"
        render_name_list_as_rtf(names)
      when "csv"
        render_name_list_as_csv(names)
      else
        flash_error(:make_report_not_supported.t(type: params[:type]))
        redirect_to(species_list_path(params[:id].to_s))
      end
    end

    ############################################################################

    include SpeciesLists::SharedPrivateMethods # shared private methods
    include SpeciesLists::SharedRenderMethods # shared private methods
  end
end
