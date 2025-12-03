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
      return unless content_present?

      # Migrated from QueuedEmail::CommercialInquiry to deliver_later.
      CommercialInquiryMailer.build(@user, @image, content).deliver_later
      flash_notice(:runtime_commercial_inquiry_success.t)

      show_flash_and_send_back
    end

    private

    def content
      params.dig(:commercial_inquiry, :content)
    end

    def content_present?
      return true if content.present?

      flash_error(:runtime_missing.t(field: :message.l))
      render(:new)
      false
    end

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
