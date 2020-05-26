# frozen_string_literal: true

# see app/controllers/names_controller.rb
class NamesController

  ##############################################################################
  #
  #  :section: Lifeforms
  #
  ##############################################################################

  def edit_lifeform
    pass_query_params
    @name = find_or_goto_index(Name, params[:id])
    return unless request.method == "POST"

    words = Name.all_lifeforms.select do |word|
      params["lifeform_#{word}"] == "1"
    end
    @name.update(lifeform: " #{words.join(" ")} ")
    # redirect_with_query(@name.show_link_args)
    redirect_to name_path(@name.id, :q => get_query_param)
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
    # redirect_with_query(@name.show_link_args)
    redirect_to name_path(@name.id, :q => get_query_param)
  end

end
