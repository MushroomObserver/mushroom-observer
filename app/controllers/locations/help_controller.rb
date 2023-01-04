# frozen_string_literal: true

# help
module Locations
  class HelpController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching
    # Help for locations
    def help; end
  end
end
