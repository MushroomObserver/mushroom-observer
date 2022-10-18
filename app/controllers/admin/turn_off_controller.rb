# frozen_string_literal: true

class Admin::TurnOffController < ApplicationController
  before_action :login_required

  def show
    session[:admin] = nil
    redirect_back_or_default("/")
  end
end
