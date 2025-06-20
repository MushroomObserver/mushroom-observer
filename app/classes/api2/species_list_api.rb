# frozen_string_literal: true

class API2
  # API for SpeciesList
  class SpeciesListAPI < ModelAPI
    def model
      SpeciesList
    end

    def high_detail_page_length
      100
    end

    def low_detail_page_length
      1000
    end

    def put_page_length
      1000
    end

    def delete_page_length
      1000
    end

    def high_detail_includes
      [
        { comments: :user },
        :location,
        :user
      ]
    end

    def query_params
      {
        id_in_set: parse_array(:species_list, :id, as: :id),
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        date: parse_range(:date, :date, help: :any_date),
        by_users: parse_array(:user, :user, help: :creator),
        locations: parse_array(:location, :location, as: :id),
        projects: parse_array(:project, :project, as: :id),
        has_notes: parse(:boolean, :has_notes),
        has_comments: parse(:boolean, :has_comments, limit: true),
        title_has: parse(:string, :title_has, help: 1),
        notes_has: parse(:string, :notes_has, help: 1),
        comments_has: parse(:string, :comments_has, help: 1),
        observation_query: parse_observation_query_parameters.compact
      }
    end

    def parse_observation_query_parameters
      parse_names_parameters.compact
    end

    def create_params
      {
        title: parse(:string, :title, limit: 100),
        when: parse(:date, :date) || Time.zone.today,
        place_name: parse(:place_name, :location,
                          limit: 1024, default: Location.unknown.display_name),
        notes: parse(:string, :notes, default: ""),
        user: @user
      }
    end

    def update_params
      parse_add_remove_observations
      {
        title: parse(:string, :set_title, limit: 100, not_blank: true),
        when: parse(:date, :set_date),
        place_name: parse(:place_name, :set_location, limit: 1024,
                                                      not_blank: true),
        notes: parse(:string, :set_notes)
      }
    end

    def validate_create_params!(params)
      make_sure_location_isnt_dubious!(params[:place_name])
      raise(MissingParameter.new(:title)) if params[:title].blank?

      title = params[:title].to_s
      return unless SpeciesList.find_by_title(title)

      raise(SpeciesListAlreadyExists.new(title))
    end

    def validate_update_params!(params)
      validate_set_location!(params)
      validate_set_title!(params)
      return unless params.empty? && @add_obs.empty? && @remove_obs.empty?

      raise(MissingSetParameters.new)
    end

    def build_setter(params)
      lambda do |spl|
        must_have_edit_permission!(spl)
        spl.update!(params)                  unless params.empty?
        spl.add_observations(@add_obs)       if @add_obs.any?
        spl.remove_observations(@remove_obs) if @remove_obs.any?
        spl
      end
    end

    ############################################################################

    private

    def validate_set_location!(params)
      name = params[:place_name].to_s
      make_sure_location_isnt_dubious!(name)
    end

    def validate_set_title!(params)
      title = params[:title].to_s
      return if query.num_results.zero?
      raise(TryingToSetMultipleLocationsToSameName.new) \
        if query.num_results > 1

      match = SpeciesList.find_by_title(title)
      return if !match || query.results.first == match

      raise(SpeciesListAlreadyExists.new(title))
    end

    def parse_add_remove_observations
      @add_obs    = parse_array(:observation, :add_observations) || []
      @remove_obs = parse_array(:observation, :remove_observations) || []
    end
  end
end
