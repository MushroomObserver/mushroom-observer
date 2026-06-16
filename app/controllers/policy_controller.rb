# frozen_string_literal: true

# Display an MO policy
class PolicyController < ApplicationController
  def privacy
    render(Views::Controllers::Policy::Privacy.new)
  end
end
