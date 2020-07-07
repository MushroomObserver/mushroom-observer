# frozen_string_literal: true

# see app/controllers/species_lists_controller.rb
class SpeciesListsController
  ##############################################################################
  #
  #  :section: Show
  #
  ##############################################################################

  def show
    store_location
    clear_query_in_session
    pass_query_params
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    @canonical_url =
      "#{MO.http_domain}/species_lists/#{@species_list.id}"
    @query = create_query(
      :Observation,
      :in_species_list,
      by: :name,
      species_list: @species_list
    )
    store_query_in_session(@query) if params[:set_source].present?
    @query.need_letters = "names.sort_name"
    @pages = paginate_letters(:letter, :page, 100)
    @objects = @query.paginate(
      @pages,
      include: [
        :user,
        :name,
        :location,
        { thumb_image: :image_votes }
      ]
    )
  end

  alias show_species_list show

  def show_next
    redirect_to_next_object(:next, SpeciesList, params[:id].to_s)
  end

  alias next_species_list show_next

  def show_prev
    redirect_to_next_object(:prev, SpeciesList, params[:id].to_s)
  end

  alias prev_species_list show_prev

  # For backwards compatibility.  Shouldn't be needed any more.
  def print_labels
    species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    query = Query.lookup_and_save(
      :SpeciesList,
      :in_species_list,
      species_list: species_list
    )
    redirect_to observations_print_labels_path(q: get_query_param(query))
  end
end
