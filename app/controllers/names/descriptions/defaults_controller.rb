# frozen_string_literal: true

#  make_description_default::    Make a description the default one.
module Names::Descriptions
  class DefaultsController < ApplicationController
    before_action :login_required

    include ::Descriptions::Defaults
    include ::Names::Descriptions::SharedPrivateMethods
  end
end
