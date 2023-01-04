# frozen_string_literal: true

module Locations::Descriptions
  module SharedPrivateMethods
    private

    def find_description(id)
      find_or_goto_index(LocationDescription, id)
    end
  end
end
