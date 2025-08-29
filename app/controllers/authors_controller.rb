# frozen_string_literal: true

class AuthorsController < ApplicationController
  before_action :login_required
end
