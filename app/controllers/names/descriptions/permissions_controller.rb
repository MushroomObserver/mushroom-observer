# frozen_string_literal: true

#  adjust_permissions::          Adjust permissions on a description.
module Names::Descriptions
  class PermissionsController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    include ::Descriptions::Permissions
  end
end
