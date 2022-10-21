# frozen_string_literal: true

module Admin
  class TurnOnController < ApplicationController
    before_action :login_required

    def show
      session[:admin] = true if @user&.admin && !in_admin_mode?
      redirect_back_or_default("/")
    end
  end
end
