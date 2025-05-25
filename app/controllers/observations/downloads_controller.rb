# frozen_string_literal: true

module Observations
  class DownloadsController < ApplicationController
    before_action :login_required

    def new
      @query = find_or_create_query(:Observation, order_by: params[:by])
      return too_many_results if too_many_results?

      query_params_set(@query)
    end

    def create
      @query = find_or_create_query(:Observation, order_by: params[:by])
      raise("no robots!") if browser.bot? # failsafe only!

      query_params_set(@query)
      @format = params[:format] || "raw"
      @encoding = params[:encoding] || "UTF-8"
      download_observations_switch
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

    def too_many_results
      flash_error(:download_observations_too_many_results.t)
      redirect_to(observations_path)
    end

    def too_many_results?
      !in_admin_mode? && @query.num_results > MO.max_downloads
    end

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
        query: @query, format: @format, encoding: @encoding, user: @user
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
      when "mycoportal"
        Report::Mycoportal.new(args)
      when "mycoportal_images"
        Report::MycoportalImages.new(args)
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
