# frozen_string_literal: true

module Observations
  # Controls viewing and modifying herbaria.
  class DownloadsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    def new; end

    def create
      @query = find_or_create_query(:Observation, by: params[:by])
      raise("no robots!") if browser.bot?

      query_params_set(@query)
      @format = params[:format] || "raw"
      @encoding = params[:encoding] || "UTF-8"
      download_observations_switch
    rescue StandardError => e
      flash_error("Internal error: #{e}", *e.backtrace[0..10])
    end

    def print_labels
      query = find_query(:Observation)
      if query
        render_report(Labels.new(query))
      else
        flash_error(:runtime_search_has_expired.t)
        redirect_back_or_default("/")
      end
    end

    private

    def download_observations_switch
      if params[:commit] == :CANCEL.l
        redirect_with_query(observations_path(always_index: true))
      elsif params[:commit] == :DOWNLOAD.l
        create_and_render_report
      elsif params[:commit] == :download_observations_print_labels.l
        render_report(Labels.new(@query))
      end
    end

    def create_and_render_report
      report = create_report(
        query: @query, format: @format, encoding: @encoding
      )
      render_report(report)
    end

    def create_report(args)
      format = args[:format].to_s
      case format
      when "raw"
        Report::Raw.new(args)
      when "adolf"
        Report::Adolf.new(args)
      when "darwin"
        Report::Dwca.new(args)
      when "symbiota"
        Report::Symbiota.new(args)
      when "fundis"
        Report::Fundis.new(args)
      else
        raise("Invalid download type: #{format.inspect}")
      end
    end

    def render_report(report)
      send_data(report.body, {
        type: report.mime_type,
        charset: report.encoding,
        disposition: "attachment",
        filename: report.filename
      }.merge(report.header || {}))
    end
  end
end
