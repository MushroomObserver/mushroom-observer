# frozen_string_literal: true

#  make_description_default::    Make a description the default one.
module Locations::Descriptions
  class DefaultsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    include ::Descriptions::Defaults
    include ::Locations::Descriptions::SharedPrivateMethods
  end
end
