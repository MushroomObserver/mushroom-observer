class AuthorController < ApplicationController

  before_action :login_required
  before_action :disable_link_prefetching

  # Form to compose email for the authors/reviewers.  Linked from show_<object>.
  # TODO: Use queued_email mechanism.
  def author_request # :norobots:
    pass_query_params
    @object = AbstractModel.find_object(params[:type], params[:id].to_s)
    return unless request.method == "POST"

    subject = param_lookup([:email, :subject], "")
    content = param_lookup([:email, :content], "")
    (@object.authors + UserGroup.reviewers.users).uniq.each do |receiver|
      AuthorEmail.build(@user, receiver, @object, subject, content).deliver_now
    end
    flash_notice(:request_success.t)
    redirect_with_query(controller: @object.show_controller,
                        action: @object.show_action, id: @object.id)
  end

  # Form to adjust permissions for a user with respect to a project.
  # Linked from: show_(object) and author_request email
  # Inputs:
  #   params[:id]
  #   params[:type]
  #   params[:add]
  #   params[:remove]
  # Success:
  #   Redraws itself.
  # Failure:
  #   Renders show_name.
  #   Outputs: @name, @authors, @users
  def review_authors # :norobots:
    pass_query_params
    @object = AbstractModel.find_object(params[:type], params[:id].to_s)
    @authors = @object.authors
    parent = @object.parent
    if @authors.member?(@user) || @user.in_group?("reviewers")
      @users = User.all.order("login, name").to_a
      new_author = params[:add] ? User.find(params[:add]) : nil
      if new_author && !@authors.member?(new_author)
        @object.add_author(new_author)
        flash_notice("Added #{new_author.legal_name}")
        # Should send email as well
      end
      old_author = params[:remove] ? User.find(params[:remove]) : nil
      if old_author && @authors.member?(old_author)
        @object.remove_author(old_author)
        flash_notice("Removed #{old_author.legal_name}")
        # Should send email as well
      end
    else
      flash_error(:review_authors_denied.t)
      redirect_with_query(controller: parent.show_controller,
                          action: parent.show_action, id: parent.id)
    end
  end
end
