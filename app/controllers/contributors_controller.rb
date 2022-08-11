# frozen_string_literal: true

# display information about user contributions to the site
class ContributorsController < ApplicationController
  before_action :disable_link_prefetching

  # Contributors index
  def index
    SiteData.new
    @users = User.by_contribution.where(contribution: 1..)
  end
end
