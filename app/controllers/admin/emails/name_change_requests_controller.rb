# frozen_string_literal: true

module Admin
  module Emails
    class NameChangeRequestsController < ApplicationController
      include ::Emailable

      before_action :login_required

      def new
        return unless check_both_names!

        unless check_different_icn_ids
          redirect_back_or_default("/")
          return
        end

        respond_to do |format|
          format.html
          format.turbo_stream do
            render(
              partial: "shared/modal_form",
              locals: { identifier: "name_change_request_email",
                        title: :email_name_change_request_title.l,
                        form: "admin/email/name_change_requests/form" }
            ) and return
          end
        end
      end

      def create
        return unless check_both_names!

        unless (name_with_icn_id = check_different_icn_ids)
          redirect_back_or_default("/")
          return
        end

        send_name_change_request(name_with_icn_id, @new_name_with_icn_id)
      end

      private

      def check_both_names!
        (@name = Name.safe_find(params[:name_id])) &&
          (@new_name_with_icn_id = params[:new_name_with_icn_id])
      end

      def check_different_icn_ids
        name_with_icn_id = "#{@name.search_name} [##{@name.icn_id}]"
        return false if name_with_icn_id == params[:new_name_with_icn_id]

        name_with_icn_id
      end

      def send_name_change_request(name_with_icn_id, new_name_with_icn_id)
        temporarily_set_locale(MO.default_locale) do
          QueuedEmail::Webmaster.create_email(
            sender_email: @user.email,
            content: change_request_content(name_with_icn_id,
                                            new_name_with_icn_id),
            subject: "Request to change Name having dependents"
          )
        end
        flash_notice(:email_change_name_request_success.t)
        redirect_to(@name.show_link_args)
      end

      def change_request_content(name_with_icn_id, new_name_with_icn_id)
        :email_name_change_request.l(
          user: @user.login,
          old_name: name_with_icn_id,
          new_name: new_name_with_icn_id,
          show_url: @name.show_url,
          edit_url: @name.edit_url,
          notes: params[:notes].to_s.strip_html.strip_squeeze
        )
      end
    end
  end
end
