# frozen_string_literal: true

# Send emails directly to the observation user via the application
module Images
  class EmailsController < ApplicationController
    include ::Emailable

    before_action :login_required

    def new
      return unless
        (@image = find_or_goto_index(Image, params[:id].to_s)) &&
        can_email_user_question?(@image, method: :email_general_commercial)

      respond_to do |format|
        format.html
        format.turbo_stream do
          render(
            partial: "shared/modal_form",
            locals: {
              title: :commercial_inquiry_title.t(
                name: @image.unique_format_name
              ),
              identifier: "commercial_inquiry_email",
              user: @user, form: "images/emails/form"
            }
          ) and return
        end
      end
    end

    def create
      return unless
        (@image = find_or_goto_index(Image, params[:id].to_s)) &&
        can_email_user_question?(@image, method: :email_general_commercial)

      content = params.dig(:commercial_inquiry, :content)
      QueuedEmail::CommercialInquiry.create_email(@user, @image, content)
      flash_notice(:runtime_commercial_inquiry_success.t)

      show_flash_and_send_back
    end

    private

    def show_flash_and_send_back
      respond_to do |format|
        format.html do
          redirect_to(image_path(@image.id)) and return
        end
        format.turbo_stream do
          render(partial: "shared/modal_flash_update",
                 locals: { identifier: "commercial_inquiry_email" }) and return
        end
      end
    end
  end
end
