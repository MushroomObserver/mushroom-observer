# frozen_string_literal: true

#  merge_descriptions::          Merge a description with another.
module Names::Descriptions
  class MergesController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching
    before_action :pass_query_params

    include ::Descriptions::Merges
    include ::Names::Descriptions::SharedPrivateMethods
  end
end
