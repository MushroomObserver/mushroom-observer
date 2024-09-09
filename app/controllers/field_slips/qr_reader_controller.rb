# frozen_string_literal: true


module FieldSlips
  class QRReaderController < ApplicationController
    before_action :login_required

    def new; end

    def create
      params = permitted_qr_params

      return unless check_for_qr_code(params)

      if @qr_code.start_with?("http")
        redirect_to(@qr_code)
      else
        @field_slip = FieldSlip.find_by(qr_code: qr_code)
        if @field_slip
          redirect_to(field_slip_path(@field_slip))
        else
          flash_error(:runtime_no_field_slip.t(id: @qr_code))
          redirect_to(new_field_slips_qr_reader_path)
        end
      end
    end

    private

    def permitted_qr_params
      params.permit(:qr_code)
    end

    def check_for_qr_code(params)
      if params[:qr_code].blank?
        flash_error(:runtime_no_qr_code.t)
        redirect_to(new_field_slips_qr_reader_path)
        return false
      end

      @qr_code = params[:qr_code]
    end
  end
end
