# frozen_string_literal: true

module Descriptions
  # manage (review: add or remove) authors of a Description
  class AuthorsController < ApplicationController
    # filters
    before_action :login_required

    def show
      set_object_and_authors
      if @authors.member?(@user) || @user.in_group?("reviewers")
        render(Views::Controllers::Descriptions::Authors::Show.new(
                 object: @object, authors: @authors.to_a
               ))
      else
        parent = @object.parent
        flash_error(:review_authors_denied.t)
        redirect_to(parent.show_link_args)
      end
    end

    def create
      set_object_and_authors
      add_ref = params[:add] || params.dig(:description_author, :user)
      add_author_matching(add_ref)
      redirect_to(action: :show)
    end

    def destroy
      set_object_and_authors
      old_author = params[:remove] ? User.safe_find(params[:remove]) : nil
      if old_author && @authors.member?(old_author)
        @object.remove_author(old_author)
        flash_notice("Removed #{old_author.legal_name}")
        # Should send email as well
      end
      redirect_to(action: :show)
    end

    private

    def set_object_and_authors
      @object = AbstractModel.find_object(params[:type], params[:id].to_s)
      @authors = @object.authors
    end

    def add_author_matching(add_ref)
      new_author = User.lookup_unique_text_name(add_ref)
      if new_author.nil?
        flash_error(:review_authors_no_user.t(login: add_ref))
      elsif @authors.member?(new_author)
        flash_error(
          :review_authors_already_author.t(login: new_author.legal_name)
        )
      else
        @object.add_author(new_author)
        flash_notice("Added #{new_author.legal_name}")
        # Should send email as well
      end
    end
  end
end
