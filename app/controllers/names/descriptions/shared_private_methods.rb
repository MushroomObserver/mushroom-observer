# frozen_string_literal: true

module Names::Descriptions
  module SharedPrivateMethods
    private

    # This either finds a description by id, or sets the ivar from the param.
    def find_description!(id = nil)
      desc_id = id || params[:id]
      @description = NameDescription.includes(show_includes).strict_loading.
                     find_by(id: desc_id) ||
                     flash_error_and_goto_index(NameDescription, desc_id)
    end

    def show_includes
      [:authors, :editors,
       { name: [:descriptions, :interests, :rss_log] },
       :project, :user, :versions]
    end
  end
end
