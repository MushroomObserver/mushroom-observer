# frozen_string_literal: true

module Locations::Descriptions
  module SharedPrivateMethods
    private

    # This either finds a description by id, or sets the ivar from the param.
    # The permissions form needs the non-strict `permissions_includes` (it
    # lazily reads `group.users.first`); everything else uses `show_includes`.
    def find_description!(id = nil, for_permissions: false)
      desc_id = id || params[:id]
      scope = if for_permissions
                LocationDescription.permissions_includes
              else
                LocationDescription.show_includes
              end
      @description = scope.safe_find(desc_id) ||
                     flash_error_and_goto_index(LocationDescription, desc_id)
    end
  end
end
