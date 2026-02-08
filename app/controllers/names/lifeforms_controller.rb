# frozen_string_literal: true

#  edit_lifeform::               Edit lifeform tags.
module Names
  class LifeformsController < ApplicationController
    before_action :login_required

    def edit
      find_name!
    end

    def update
      return unless find_name!

      words = Name.all_lifeforms.select do |word|
        params.dig(:lifeform, word)&.to_s == "1"
      end
      @name.update(lifeform: " #{words.join(" ")} ")
      redirect_to(@name.show_link_args)
    end

    private

    def find_name!
      @name = find_or_goto_index(Name, params[:id])
    end
  end
end
