# frozen_string_literal: true

module Names::Descriptions
  module SharedPrivateMethods
    private

    def find_description(id)
      find_or_goto_index(NameDescription, id)
    end
  end
end
