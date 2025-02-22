# frozen_string_literal: true

module Query::Titles::Observations
  MAX_TITLE_ITEMS = 3

  def with_observations_query_description
    return nil unless (description = observation_query_description)

    if params.deep_find(:search_user).blank?
      :query_title_with_observations_filtered.t(type: model.type_tag,
                                                subtitle: description)
    else
      :query_title_with_observations_by_user.t(type: model.type_tag,
                                               user: description)
    end
  end

  def observation_query_description
    return nil unless (params.keys - [:by]).any?

    # For now just deal with simple cases which correspond more or less
    # to the old flavors.
    args = [
      :herbaria, :locations, :names, :projects, :project_lists,
      :species_lists, :by_users, :search_user
    ].reject { |arg| params.deep_find(arg).first.blank? }

    if args.length == 1
      send(:"title_for_#{args.first}")
    else
      :query_title_all_filtered.t(type: :observation)
    end
  end

  private

  def title_for_herbaria
    str = map_join_and_truncate(:herbaria, Herbarium, :name)
    :query_title_in_herbarium.t(type: :observation, herbarium: str)
  end

  # NOTE: used in "Locations with Observations of {name}" - AN 2023
  def title_for_locations
    str = map_join_and_truncate(:locations, Location, :display_name)
    :query_title_at_location.t(type: :observation, location: str)
  end

  def title_for_names
    str = map_join_and_truncate(:names, Name, :text_name)
    :query_title_of_name.t(type: :observation, name: str)
  end

  def title_for_projects
    str = map_join_and_truncate(:projects, Project, :title)
    :query_title_for_project.t(type: :observation, project: str)
  end

  def title_for_project_lists
    str = map_join_and_truncate(:project_lists, Project, :title)
    :query_title_in_lists_for_project.t(type: :observation, project: str)
  end

  def title_for_species_lists
    str = map_join_and_truncate(:species_lists, SpeciesList, :title)
    :query_title_in_species_list.t(type: :observation, species_list: str)
  end

  def title_for_by_users
    str = if params.deep_find(:by_users).size == 1
            User.find(params.deep_find(:by_users).first).legal_name
          else
            map_join_and_truncate(:by_users, User, :login)
          end
    :query_title_by_user.t(type: :observation, user: str)
  end

  # takes a search string
  def title_for_search_user
    user = params.deep_find(:search_user)
    :query_title_by_user.t(type: :observation, user:)
  end

  def map_join_and_truncate(param, model, method)
    str = params.deep_find(param)[0..(MAX_TITLE_ITEMS - 1)].map do |val|
      # Integer(val) throws ArgumentError if val is not an integer.
      get_attribute_of_instance_by_integer(val, model, method)
    rescue ArgumentError # rubocop:disable Layout/RescueEnsureAlignment
      val
    end.join(", ")
    if str.length > 100
      str = "#{str[0...97]}..."
    elsif params.deep_find(param).length > MAX_TITLE_ITEMS
      str += ", ..."
    end
    str
  end

  def get_attribute_of_instance_by_integer(val, model, method)
    val = val.min if val.is_a?(Array)
    return val if val.is_a?(AbstractModel)

    model.find(Integer(val)).send(method)
  end
end
