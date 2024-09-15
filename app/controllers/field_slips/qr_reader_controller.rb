# frozen_string_literal: true

module FieldSlips
  class QRReaderController < ApplicationController
    before_action :login_required

    def new; end

    def create
      params = permitted_qr_params
      return unless check_for_qr_code(params)

      redirect_to("#{MO.http_domain}/qr/#{@qr_code.strip}")
    end

    private

    def permitted_qr_params
      params.permit(:qr_code)
    end

    def check_for_qr_code(params)
      @qr_code = params[:qr_code]
      if @qr_code.start_with?("http")
        if @qr_code.start_with?("https://mushroomobserver.org/qr/")
          @qr_code = @qr_code.split("/")[-1]
          return true
        end
      elsif @qr_code.present?
        return true
      end

      flash_error(:runtime_bad_qr_code.t(code: @qr_code))
      redirect_to(field_slips_qr_reader_new_path)
      false
    end
  end
end
