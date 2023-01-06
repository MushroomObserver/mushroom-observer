# frozen_string_literal: true

module Names::Descriptions
  module SharedPrivateMethods
    private

    def find_description!
      @description = find_or_goto_index(NameDescription, params[:id].to_s)
    end
  end
end
