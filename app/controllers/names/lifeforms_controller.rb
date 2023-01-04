# frozen_string_literal: true

#  == LIFEFORMS
#  edit_lifeform::               Edit lifeform tags.
#  propagate_lifeform::          Add/remove lifeform tags to/from subtaxa.

module Names
  class LifeformsController < ApplicationController
    def edit_lifeform
      pass_query_params
      @name = find_or_goto_index(Name, params[:id])
      return unless request.method == "POST"

      words = Name.all_lifeforms.select do |word|
        params["lifeform_#{word}"] == "1"
      end
      @name.update(lifeform: " #{words.join(" ")} ")
      redirect_with_query(@name.show_link_args)
    end

    def propagate_lifeform
      pass_query_params
      @name = find_or_goto_index(Name, params[:id])
      return unless request.method == "POST"

      Name.all_lifeforms.each do |word|
        if params["add_#{word}"] == "1"
          @name.propagate_add_lifeform(word)
        elsif params["remove_#{word}"] == "1"
          @name.propagate_remove_lifeform(word)
        end
      end
      redirect_with_query(@name.show_link_args)
    end
  end
end
