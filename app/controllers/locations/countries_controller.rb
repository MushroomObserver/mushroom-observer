# frozen_string_literal: true

# list_countries
module Locations
  class CountriesController < ApplicationController
    before_action :login_required

    # Displays a list of all countries with counts.
    def index
      @cc = ::CountryCounter.new
      render(Views::Controllers::Locations::Countries::Index.new(cc: @cc))
    end
  end
end
