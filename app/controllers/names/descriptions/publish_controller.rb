# frozen_string_literal: true

#  publish_description::       Publish a draft description.
module Names::Descriptions
  class PublishController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    include ::Descriptions::Publish
    include ::Names::Descriptions::SharedPrivateMethods
  end
end
