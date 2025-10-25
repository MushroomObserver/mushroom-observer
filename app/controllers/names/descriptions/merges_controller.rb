# frozen_string_literal: true

#  merge_descriptions::          Merge a description with another.
module Names::Descriptions
  class MergesController < ApplicationController
    before_action :login_required

    include ::Descriptions::Merges
    include ::Names::Descriptions::SharedPrivateMethods
  end
end
