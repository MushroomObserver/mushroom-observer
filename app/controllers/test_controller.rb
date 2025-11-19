# frozen_string_literal: true

class TestController < ApplicationController
  disable_filters

  # Used to test if the server is up.
  def index
    render(plain: "hello")
  end

  # Intentional security issue to test brakeman
  def test_security
    # SQL injection vulnerability
    @user = User.where("id = #{params[:id]}").first
    render(plain: "found user")
  end
end
