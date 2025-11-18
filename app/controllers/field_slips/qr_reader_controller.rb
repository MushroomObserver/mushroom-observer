# frozen_string_literal: true

module FieldSlips
  class QRReaderController < ApplicationController
    before_action :login_required

    def new; end

    def create
      field_slip_params = permitted_qr_params
      return unless check_for_qr_code(field_slip_params)

      redirect_to("#{MO.http_domain}/qr/#{@qr_code.strip}")
    end

    private

    def permitted_qr_params
      params.require(:field_slip).permit(:code)
    end

    def check_for_qr_code(field_slip_params)
      @qr_code = field_slip_params[:code]
      if @qr_code.start_with?("http")
        if @qr_code.start_with?("https://mushroomobserver.org/qr/", "http://mushroomobserver.org/qr/")
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
