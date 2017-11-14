class API
  # API for SpeciesList
  class SpeciesListAPI < ModelAPI
    self.model = SpeciesList

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :comments,
      :user
    ]

    def query_params
      {
        where:          sql_id_condition,
        created_at:     parse_range(:time, :created_at),
        updated_at:     parse_range(:time, :updated_at),
        date:           parse(:date, :date),
        users:          parse_array(:user, :user),
        names:          parse_array(:string, :name),
        synonym_names:  parse_array(:string, :synonyms_of),
        children_names: parse_array(:string, :children_of),
        locations:      parse_array(:string, :location),
        projects:       parse_array(:string, :project),
        has_notes:      parse(:boolean, :has_notes),
        has_comments:   parse(:boolean, :has_comments, limit: true),
        title_has:      parse(:string, :title_has),
        notes_has:      parse(:string, :notes_has),
        comments_has:   parse(:string, :comments_has)
      }
    end

    def create_params
      {
        title:      parse(:string, :title, limit: 100),
        when:       parse(:date, :date, default: Date.today),
        place_name: parse(:place_name, :location, limit: 1024,
                                                  default: Location.unknown),
        notes:      parse(:string, :notes, default: "")
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:title) if params[:title].blank?
      title = params[:title].to_s
      return unless SpeciesList.find_by_title(title)
      raise SpeciesListAlreadyExists.new(title)
    end

    def build_setter
      parse_add_remove_observations
      params = update_params
      params.remove_nils!
      make_sure_parameters_not_empty!
      lambda do |spl|
        must_have_edit_permission!(spl)
        spl.update!(params)                  unless params.empty?
        spl.add_observations(@add_obs)       if @add_obs.any?
        spl.remove_observations(@remove_obs) if @remove_obs.any?
      end
    end

    def update_params
      {
        title:      parse(:string, :set_title, limit: 100),
        when:       parse(:date, :set_date),
        place_name: parse(:place_name, :set_location, limit: 1024),
        notes:      parse(:string, :set_notes)
      }
    end

    def parse_add_remove_observations
      @add_obs    = parse_array(:observation, :add_observations) || []
      @remove_obs = parse_array(:observation, :remove_observations) || []
    end

    def make_sure_parameters_not_empty!
      return unless params.empty? && @add_obs.empty? && @remove_obs.empty?
      raise MissingSetParameters.new
    end
  end
end
