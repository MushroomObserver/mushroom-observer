# frozen_string_literal: true

#  adjust_permissions::          Adjust permissions on a description.
module Names::Descriptions
  class PermissionsController < ApplicationController
    before_action :login_required

    include ::Descriptions::Permissions
    include ::Names::Descriptions::SharedPrivateMethods
  end
end
