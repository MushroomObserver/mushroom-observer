# frozen_string_literal: true

module SpeciesLists
  class DownloadsController < ApplicationController
    include DownloadFormatValidatable

    before_action :login_required

    ############################################################################
    #
    #  :section: Reports
    #
    ############################################################################

    # Template shows three forms: print_labels, make_report, and download obs
    def new
      @list = find_species_list!
      @type = valid_report_type(species_list_report_format)
      @format = valid_download_format(params[:format])
      @encoding = valid_download_encoding(params[:encoding])
      @query = lookup_species_list_query(@list)
      render(
        Views::Controllers::SpeciesLists::Downloads::New.new(
          list: @list,
          query: @query,
          type: @type,
          format: @format,
          encoding: @encoding
        )
      )
    end

    def create
      @list = find_species_list!
      @type = valid_report_type(species_list_report_format)
      @format = valid_download_format(params[:format])
      @encoding = valid_download_encoding(params[:encoding])
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
      Query.lookup_and_save(:Observation, species_lists: list)
    end

    # Used by download.
    def make_report
      return unless (@species_list = find_species_list!)

      names = @species_list.names
      # @type is already validated against report_types (falls back
      # to "txt"), so every branch here is reachable -- no else needed.
      case @type
      when "txt"
        render_name_list_as_txt(names)
      when "rtf"
        render_name_list_as_rtf(names)
      when "csv"
        render_name_list_as_csv(names)
      end
    end

    # Read the report-format choice posted by
    # `Views::Controllers::SpeciesLists::Downloads::ReportForm` under
    # the `species_list_report[format]` namespace.
    def species_list_report_format
      params.dig(:species_list_report, :format)
    end

    # Only for the `new` action's radio pre-selection -- silently
    # falling back to the default is harmless there. `make_report`'s
    # own `case`/`else` above is the real validator for report
    # generation, with a user-facing error; this must NOT replace it,
    # or an invalid type would silently become a txt report instead
    # of showing that error.
    def report_types
      %w[txt rtf csv].freeze
    end

    def valid_report_type(value, default: "txt")
      report_types.include?(value) ? value : default
    end

    ############################################################################

    include SpeciesLists::SharedPrivateMethods # shared private methods
    include SpeciesLists::SharedRenderMethods # shared private methods
  end
end
