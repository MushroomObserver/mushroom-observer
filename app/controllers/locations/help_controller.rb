# frozen_string_literal: true

# help
module Locations
  class HelpController < ApplicationController
    before_action :login_required
    # Help for locations
    def show; end
  end
end
