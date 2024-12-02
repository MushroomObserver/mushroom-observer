# frozen_string_literal: true

module Query
  class FieldSlipBase < Query::Base
    def model
      FieldSlip
    end

    def parameter_declarations
      super.merge(
        created_at?: [:time],
        updated_at?: [:time],
        users?: [User],
        code?: :string,
        observation?: Observation,
        projects?: [:string]
      )
    end

    def initialize_flavor
      add_owner_and_time_stamp_conditions("field_slips")
      add_for_observation_condition
      initialize_projects_parameter
      initialize_code_match_parameter
      super
    end

    def add_for_observation_condition
      return if params[:observation].blank?

      obs = find_cached_parameter_instance(Observation, :observation)
      @title_tag = :query_title_for_observation
      @title_args[:observation] = obs.unique_format_name
      where << "field_slips.observation_id = '#{obs.id}'"
    end

    def initialize_projects_parameter
      return if params[:projects].blank?

      add_id_condition(
        "field_slips.project_id",
        lookup_projects_by_name(params[:projects]),
        :projects
      )
    end

    def initialize_code_match_parameter
      return if params[:code].blank?

      add_exact_match_condition("field_slips.code", params[:code])
    end

    def self.default_order
      "code"
    end
  end
end
