# frozen_string_literal: true

# propagate_lifeform
module Names::Lifeforms
  class PropagateController < ApplicationController
    before_action :login_required

    def edit
      pass_query_params
      @name = find_or_goto_index(Name, params[:id])
    end

    def update
      pass_query_params
      @name = find_or_goto_index(Name, params[:id])

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
