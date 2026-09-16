# frozen_string_literal: true

module Admin
  module Emails
    class MergeRequestsController < ApplicationController
      before_action :login_required

      def new
        return unless (@model = validate_merge_model!(params[:type]))

        unless validate_objects!
          redirect_back_or_default("/")
          return
        end

        respond_to do |format|
          format.html do
            render(Views::Controllers::Admin::Emails::MergeRequests::New.new(
                     model: @model, old_obj: @old_obj, new_obj: @new_obj
                   ))
          end
          format.turbo_stream do
            render(Components::Modal.new(
                     type: :turbo_form,
                     identifier: "merge_request_email",
                     title: :email_merge_request_title.t(type: @model.type_tag),
                     user: @user,
                     model: FormObject::EmailRequest.new,
                     form_class:
                       Views::Controllers::Admin::Emails::MergeRequests::Form,
                     form_locals: { old_obj: @old_obj, new_obj: @new_obj,
                                    model_class: @model, user: @user }
                   ), layout: false)
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
          flash_error(:runtime_invalid.t(type: '"type"', value: val.to_s))
          redirect_back_or_default("/")
          nil
        end
      end

      def send_merge_request
        # Migrated from QueuedEmail::Webmaster to ActionMailer + ActiveJob.
        # No temporarily_set_locale wrapper needed here (unlike the
        # sibling email controllers) -- MergeRequestMailer#build sets
        # the locale itself, since the tag resolution now happens in
        # its Phlex view, not eagerly in this action.
        notes = params.dig(:email, :message)
        MergeRequestMailer.build(
          sender_email: @user.email,
          old_obj: @old_obj,
          new_obj: @new_obj,
          user: @user,
          notes: notes.to_s.strip_html.strip_squeeze
        ).deliver_later
        flash_notice(:email_merge_request_success.t)
        redirect_to(@old_obj.show_link_args)
      end
    end
  end
end
