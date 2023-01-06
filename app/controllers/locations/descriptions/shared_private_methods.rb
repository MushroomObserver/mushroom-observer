# frozen_string_literal: true

module Locations::Descriptions
  module SharedPrivateMethods
    private

    def find_description!
      @description = find_or_goto_index(LocationDescription, params[:id].to_s)
    end
  end
end
