# frozen_string_literal: true

module Authors
  # request to be an object author
  class EmailRequestsController < ApplicationController
    # filters
    before_action :login_required
    before_action :pass_query_params

    # Form to compose email for the authors/reviewers.
    # Linked from show_<object>.
    def new
      @object = AbstractModel.find_object(params[:type], params[:id].to_s)
    end

    def create
      @object = AbstractModel.find_object(params[:type], params[:id].to_s)
      send_author_emails
      flash_notice(:request_success.t)
      redirect_with_query(controller: @object.show_controller,
                          action: @object.show_action, id: @object.id)
    end

    private

    # TODO: Use QueuedEmail mechanism
    def send_author_emails
      subject = param_lookup([:email, :subject], "")
      content = param_lookup([:email, :content], "")

      (@object.authors + UserGroup.reviewers.users).uniq.each do |receiver|
        AuthorMailer.build(@user, receiver, @object, subject,
                           content).deliver_now
      end
    end
  end
end
