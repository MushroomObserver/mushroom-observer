# frozen_string_literal: true

module Names::Descriptions
  module SharedPrivateMethods
    private

    # This either finds a description by id, or sets the ivar from the param.
    def find_description!(id = nil)
      return find_or_goto_index(NameDescription, id) if id

      @description = find_or_goto_index(NameDescription, params[:id].to_s)
    end
  end
end
