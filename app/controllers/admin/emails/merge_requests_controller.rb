# frozen_string_literal: true

module Admin
  module Emails
    class MergeRequestsController < AdminController
      include ::Emailable

      before_action :login_required

      def new
        return unless (@model = validate_merge_model!(params[:type]))

        unless validate_model_and_objects!
          redirect_back_or_default("/")
          return
        end

        respond_to do |format|
          format.html
          format.turbo_stream do
            render(
              partial: "shared/modal_form",
              locals: { identifier: "merge_request_email",
                        title: :email_merge_request_title.t(
                          type: @model.type_tag
                        ),
                        form: "admin/email/merge_requests/form" }
            ) and return
          end
        end
      end

      def create
        return unless (@model = validate_merge_model!(params[:type]))

        unless validate_objects!
          redirect_back_or_default("/")
          return
        end

        send_merge_request
      end

      private

      def validate_objects!
        @old_obj = @model.safe_find(params[:old_id])
        @new_obj = @model.safe_find(params[:new_id])
        return false if !@old_obj || !@new_obj || @old_jb == @new_obj

        true
      end

      def validate_merge_model!(val)
        case val
        when "Herbarium"
          Herbarium
        when "Location"
          Location
        when "Name"
          Name
        else
          flash_error("Invalid type param: #{val.inspect}.")
          redirect_back_or_default("/")
          nil
        end
      end

      def send_merge_request
        temporarily_set_locale(MO.default_locale) do
          QueuedEmail::Webmaster.create_email(
            sender_email: @user.email,
            subject: "#{@model.name} Merge Request",
            content: merge_request_content
          )
        end
        flash_notice(:email_merge_request_success.t)
        redirect_to(@old_obj.show_link_args)
      end

      def merge_request_content
        :email_merge_objects.l(
          user: @user.login,
          type: @model.type_tag,
          this: @old_obj.merge_info,
          that: @new_obj.merge_info,
          show_this_url: @old_obj.show_url,
          show_that_url: @new_obj.show_url,
          edit_this_url: @old_obj.edit_url,
          edit_that_url: @new_obj.edit_url,
          notes: params[:notes].to_s.strip_html.strip_squeeze
        )
      end
    end
  end
end
