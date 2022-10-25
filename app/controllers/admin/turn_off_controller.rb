# frozen_string_literal: true

module Admin
  class TurnOffController < ApplicationController
    before_action :login_required

    def show
      session[:admin] = nil
      redirect_back_or_default("/")
    end
  end
end
