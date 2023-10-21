# frozen_string_literal: true

#  make_description_default::    Make a description the default one.
module Locations::Descriptions
  class DefaultsController < ApplicationController
    before_action :login_required

    include ::Descriptions::Defaults
    include ::Locations::Descriptions::SharedPrivateMethods
  end
end
