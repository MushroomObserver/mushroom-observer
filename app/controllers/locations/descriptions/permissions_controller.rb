# frozen_string_literal: true

#  adjust_permissions::          Adjust permissions on a description.
module Locations::Descriptions
  class PermissionsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching
    before_action :pass_query_params

    include ::Descriptions::Permissions
    include ::Locations::Descriptions::SharedPrivateMethods
  end
end
