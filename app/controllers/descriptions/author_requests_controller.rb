# frozen_string_literal: true

module Descriptions
  # request to be an Description author
  class AuthorRequestsController < ApplicationController
    # filters
    before_action :login_required

    # Form to compose email for the authors/reviewers.
    # Linked from show_<object>.
    def new
      @object = AbstractModel.find_object(params[:type], params[:id].to_s)
    end

    def create
      @object = AbstractModel.find_object(params[:type], params[:id].to_s)
      send_author_emails
      flash_notice(:request_success.t)
      redirect_to(@object.show_link_args)
    end

    private

    def send_author_emails
      subject = params.dig(:email, :subject).to_s
      content = params.dig(:email, :content).to_s

      (@object.authors + UserGroup.reviewers.users).uniq.each do |receiver|
        QueuedEmail::AuthorRequest.create_email(@user, receiver, @object,
                                                subject, content)
      end
    end
  end
end
