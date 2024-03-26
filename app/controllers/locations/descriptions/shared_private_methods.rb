# frozen_string_literal: true

module Locations::Descriptions
  module SharedPrivateMethods
    private

    # This either finds a description by id, or sets the ivar from the param.
    def find_description!(id = nil)
      desc_id = id || params[:id] || params[:description_id]
      @description = LocationDescription.show_includes.safe_find(desc_id) ||
                     flash_error_and_goto_description_index(desc_id)
    end

    def flash_error_and_goto_description_index(id)
      flash_error(:runtime_object_not_found.t(
                    id: id || "0", type: LocationDescription.type_tag
                  ))
      redirect_with_query(controller: :locations, action: :index)
    end
  end
end
