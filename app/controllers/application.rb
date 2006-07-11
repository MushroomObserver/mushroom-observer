# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'login_system'

CSS = ['Agaricus', 'Amanita']

class ApplicationController < ActionController::Base
  include LoginSystem
  model :user
end