# frozen_string_literal: true

module Locations::Descriptions
  module SharedPrivateMethods
    private

    # This either finds a description by id, or sets the ivar from the param.
    def find_description!(id = nil)
      return find_or_goto_index(LocationDescription, id) if id

      @description = find_or_goto_index(LocationDescription, params[:id].to_s)
    end
  end
end
