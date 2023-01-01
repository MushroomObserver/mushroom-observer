# frozen_string_literal: true

module SpeciesLists
  class DownloadsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    ############################################################################
    #
    #  :section: Reports
    #
    ############################################################################

    # This shows two forms: print_labels and make_report
    def new
      pass_query_params
      @list = find_or_goto_index(SpeciesList, params[:id].to_s)
      @type = params[:type] || "txt"
      @format = params[:format] || "raw"
      @encoding = params[:encoding] || "UTF-8"
      @query = lookup_species_list_query(@list)
    end

    def print_labels
      species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
      query = lookup_species_list_query(species_list)
      redirect_with_query(print_labels_for_observations_path, query)
    end

    def lookup_species_list_query(list)
      Query.lookup_and_save(:Observation, :in_species_list,
                            species_list: list)
    end

    # Used by download.
    def make_report
      @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
      return unless @species_list

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
        redirect_to(action: :show, id: params[:id].to_s)
      end
    end

    def render_name_list_as_txt(names)
      charset = "UTF-8"
      str = "\xEF\xBB\xBF#{names.map(&:real_search_name).join("\r\n")}"
      send_data(str, type: "text/plain",
                     charset: charset,
                     disposition: "attachment",
                     filename: "report.txt")
    end

    def render_name_list_as_csv(names)
      charset = "ISO-8859-1"
      str = CSV.generate do |csv|
        csv << %w[scientific_name authority citation accepted]
        names.each do |name|
          csv << [name.real_text_name, name.author, name.citation,
                  name.deprecated ? "" : "1"].map(&:presence)
        end
      end
      str = str.iconv(charset)
      send_data(str, type: "text/csv",
                     charset: charset,
                     header: "present",
                     disposition: "attachment",
                     filename: "report.csv")
    end

    def render_name_list_as_rtf(names)
      charset = "UTF-8"
      doc = RTF::Document.new(RTF::Font::SWISS)
      reportable_ranks = %w[Genus Species Subspecies Variety Form]
      names.each do |name|
        rank      = name.rank
        text_name = name.real_text_name
        author    = name.author
        node      = name.deprecated ? doc : doc.bold
        node      = node.italic if reportable_ranks.include?(rank)
        node << text_name
        doc << " #{author}" if author.present?
        doc.line_break
      end
      send_data(doc.to_rtf, type: "text/rtf",
                            charset: charset,
                            disposition: "attachment",
                            filename: "report.rtf")
    end
  end
end
