# frozen_string_literal: true

#  edit_lifeform::               Edit lifeform tags.
module Names
  class LifeformsController < ApplicationController
    before_action :login_required

    def edit
      pass_query_params
      find_name!
    end

    def update
      pass_query_params
      return unless find_name!

      words = Name.all_lifeforms.select do |word|
        params.dig(:lifeform, word) == "1"
      end
      @name.update(lifeform: " #{words.join(" ")} ")
      redirect_with_query(@name.show_link_args)
    end

    private

    def find_name!
      @name = find_or_goto_index(Name, params[:id])
    end
  end
end
