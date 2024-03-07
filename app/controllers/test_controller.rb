# frozen_string_literal: true

class TestController < ApplicationController
  disable_filters

  # Used to test if the server is up.
  def index
    render(plain: "hello")
  end
end
