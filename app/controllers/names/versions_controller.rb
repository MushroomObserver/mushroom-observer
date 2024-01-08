# frozen_string_literal: true

# show_past_name
module Names
  class VersionsController < ApplicationController
    before_action :login_required

    # Show past version of Name.  Accessible only from show_name page.
    def show
      pass_query_params
      store_location
      return unless find_name!

      @name.revert_to(params[:version].to_i)
      @versions = @name.versions
      @correct_spelling = ""
      return unless @name.is_misspelling?

      # Old correct spellings could have gotten merged with something else
      # and no longer exist. Note: this is a second db lookup
      @correct_spelling = Name.where(id: @name.correct_spelling_id).
                          pluck(:display_name)
    end

    def find_name!
      @name = Name.includes(show_includes).strict_loading.
              find_by(id: params[:id]) ||
              flash_error_and_goto_index(Name, params[:id])
    end

    def show_includes
      [:correct_spelling,
       { observations: :user },
       :user, :versions]
    end
  end
end
