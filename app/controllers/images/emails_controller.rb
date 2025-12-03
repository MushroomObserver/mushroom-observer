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
      image = find_or_goto_index(Image, params[:id].to_s)
      return unless image &&
                    can_email_user_question?(image,
                                             method: :email_general_commercial)
      return unless content_present?(image)

      # Migrated from QueuedEmail::CommercialInquiry to deliver_later.
      message = params.dig(:commercial_inquiry, :content)
      CommercialInquiryMailer.build(
        sender: @user, image:, message:
      ).deliver_later
      flash_notice(:runtime_commercial_inquiry_success.t)

      show_flash_and_send_back(image)
    end

    private

    def content_present?(image)
      return true if params.dig(:commercial_inquiry, :content).present?

      flash_error(:runtime_missing.t(field: :message.l))
      @image = image
      render(:new)
      false
    end

    def show_flash_and_send_back(image)
      respond_to do |format|
        format.html do
          redirect_to(image_path(image.id)) and return
        end
        format.turbo_stream do
          render(partial: "shared/modal_flash_update",
                 locals: { identifier: "commercial_inquiry_email" }) and return
        end
      end
    end
  end
end
