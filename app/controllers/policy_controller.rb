# frozen_string_literal: true

# Display an MO policy
class PolicyController < ApplicationController
  skip_before_action :redirect_anonymous_users

  def privacy; end
end
