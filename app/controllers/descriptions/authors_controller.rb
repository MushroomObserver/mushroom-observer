# frozen_string_literal: true

module Descriptions
  # manage (review: add or remove) authors of a Description
  class AuthorsController < ApplicationController
    # filters
    before_action :login_required
    before_action :pass_query_params

    def show
      set_object_and_authors
      if @authors.member?(@user) || @user.in_group?("reviewers")
        @users = User.order("login, name").to_a
      else
        parent = @object.parent
        flash_error(:review_authors_denied.t)
        redirect_with_query(controller: parent.show_controller,
                            action: parent.show_action, id: parent.id)
      end
    end

    def create
      set_object_and_authors
      new_author = params[:add] ? User.find(params[:add]) : nil
      return unless new_author && !@authors.member?(new_author)

      @object.add_author(new_author)
      flash_notice("Added #{new_author.legal_name}")
      # Should send email as well
      redirect_to(action: :show)
    end

    def destroy
      set_object_and_authors
      old_author = params[:remove] ? User.find(params[:remove]) : nil
      return unless old_author && @authors.member?(old_author)

      @object.remove_author(old_author)
      flash_notice("Removed #{old_author.legal_name}")
      # Should send email as well
      redirect_to(action: :show)
    end

    private

    def set_object_and_authors
      @object = AbstractModel.find_object(params[:type], params[:id].to_s)
      @authors = @object.authors
    end
  end
end
