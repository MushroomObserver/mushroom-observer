# frozen_string_literal: true

#  merge_descriptions::          Merge a description with another.
module Locations::Descriptions
  class MergesController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    include ::Descriptions::Merges
    include ::Locations::Descriptions::SharedPrivateMethods
  end
end
