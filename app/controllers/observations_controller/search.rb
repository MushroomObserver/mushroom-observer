# see observations_controller.rb
# Called from SearchController. see search_controller.rb
#    ImageController, LocationController and NameController also have versions
class ObservationsController
  # Displays matrix of advanced search results.
  def advanced_search # :norobots:
    if params[:name] || params[:location] || params[:user] || params[:content]
      search = {}
      search[:name] = params[:name] if params[:name].present?
      search[:location] = params[:location] if params[:location].present?
      search[:user] = params[:user] if params[:user].present?
      search[:content] = params[:content] if params[:content].present?
      search[:search_location_notes] = params[:search_location_notes].present?
      query = create_query(:Observation, :advanced_search, search)
    else
      query = find_query(:Observation)
    end
    show_selected_observations(query)
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    redirect_to(controller: :search, action: :advanced_search_form)
  end
end
