# frozen_string_literal: true

# display information about user contributions to the site
class ContributorsController < ApplicationController
  before_action :login_required

  # Contributors index
  def index
    query = create_query(:User, :all, with_contribution: true,
                                      by: :contribution)
    args = { action: :index, matrix: true, include: [:image] }

    show_index_of_objects(query, args)
  end
end
