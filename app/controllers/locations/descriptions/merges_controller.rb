# frozen_string_literal: true

#  merge_descriptions::          Merge a description with another.
module Locations::Descriptions
  class MergesController < ApplicationController
    before_action :login_required

    include ::Descriptions::Merges
    include ::Locations::Descriptions::SharedPrivateMethods
  end
end
