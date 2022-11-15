# frozen_string_literal: true

class AuthorsController < ApplicationController
  before_action :login_required
  before_action :pass_query_params

  # "Form" (or rather, a page with links back to itself that add params)
  # to adjust permissions for a user with respect to a project.
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
  # def review
  #   @object = AbstractModel.find_object(params[:type], params[:id].to_s)
  #   @authors = @object.authors
  #   deal_with_additions_or_removals
  # end

  # private

  # def deal_with_additions_or_removals
  #   if @authors.member?(@user) || @user.in_group?("reviewers")
  #     @users = User.all.order("login, name").to_a
  #     maybe_add_user_as_author
  #     maybe_remove_user_as_author
  #   else
  #     parent = @object.parent
  #     flash_error(:review_authors_denied.t)
  #     redirect_with_query(controller: parent.show_controller,
  #                         action: parent.show_action, id: parent.id)
  #   end
  # end

  # def maybe_add_user_as_author
  #   new_author = params[:add] ? User.find(params[:add]) : nil
  #   return unless new_author && !@authors.member?(new_author)

  #   @object.add_author(new_author)
  #   flash_notice("Added #{new_author.legal_name}")
  #   # Should send email as well
  # end

  # def maybe_remove_user_as_author
  #   old_author = params[:remove] ? User.find(params[:remove]) : nil
  #   return unless old_author && @authors.member?(old_author)

  #   @object.remove_author(old_author)
  #   flash_notice("Removed #{old_author.legal_name}")
  #   # Should send email as well
  # end
end
