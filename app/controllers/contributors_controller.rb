# frozen_string_literal: true

# display information about user contributions to the site
class ContributorsController < ApplicationController
  before_action :login_required

  # Contributors index
  def index
    # @users = User.by_contribution.where(contribution: 1..)
    query = create_query(:User, :with_contribution, by: :contribution)
    args = { action: :index, matrix: true, include: [:thumb_image] }

    show_index_of_objects(query, args)
  end
end
