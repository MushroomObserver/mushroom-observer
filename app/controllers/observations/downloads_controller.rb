# frozen_string_literal: true

module Observations
  class DownloadsController < ApplicationController
    before_action :login_required

    def new
      @query = find_or_create_query(:Observation, order_by: params[:by])
      return too_many_results if too_many_results?

      update_stored_query(@query) # also stores query in session
    end

    def create
      @query = find_or_create_query(:Observation, order_by: params[:by])
      raise("no robots!") if browser.bot? # failsafe only!

      update_stored_query(@query) # also stores query in session
      @format = params[:format] || "raw"
      @encoding = params[:encoding] || "UTF-8"
      download_observations_switch
    end

    def print_labels
      query = find_query(:Observation)
      if query
        render_report(LabelDocument.new(query, 8.5, 11))
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
        render_report(LabelDocument.new(@query, 8.5, 11))
      end
    end

    def create_and_render_report
      report = create_report(
        query: @query, format: @format, encoding: @encoding, user: @user
      )
      render_report(report)
    end

    FORMATS = %w[
      raw
      adolf
      dwca
      symbiota
      fundis
      mycoportal
      mycoportal_image_list
    ].freeze
    private_constant :FORMATS

    def create_report(args)
      format = args[:format].to_s
      return do_report(args, format) if FORMATS.include?(format)

      raise("Invalid download type: #{format.inspect}")
    end

    def do_report(args, format)
      report_class =
        "Report::#{format.split("_").map(&:capitalize).join}".constantize
      report_class.new(args)
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
