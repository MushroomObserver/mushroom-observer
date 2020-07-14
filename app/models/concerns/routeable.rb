# frozen_string_literal: true
# https://www.dwightwatson.com/posts/accessing-rails-routes-helpers-from-anywhere-in-your-app
# https://stackoverflow.com/questions/43355582/rails-make-route-helper-methods-available-to-poro

module Routeable
  extend ActiveSupport::Concern

  # included do
  #   include Rails.application.routes.url_helpers
  # end
  #
  # def default_url_options
  #   Rails.application.config.action_mailer.default_url_options
  # end

  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper

  def url_helpers
    Rails.application.routes.url_helpers
  end

end
