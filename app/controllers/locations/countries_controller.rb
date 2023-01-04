# frozen_string_literal: true

# list_countries
module Locations
  class CountriesController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching
  end

  # Displays a list of all countries with counts.
  def list_countries
    @cc = CountryCounter.new
  end
end
