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
        by_user?: User,
        code?: :string,
        observation?: Observation,
        project?: Project
      )
    end

    def initialize_flavor
      add_owner_and_time_stamp_conditions("field_slips")
      add_by_user_condition("field_slips")
      # add_for_observation_condition # This servers no clear purpose
      add_for_project_condition
      # initialize_code_match_parameter # This servers no clear purpose
      super
    end

    # I see no reason why we would want to search for field slips by
    # observation.
    #
    # def add_for_observation_condition
    #   return if params[:observation].blank?

    #   obs = find_cached_parameter_instance(Observation, :observation)
    #   @title_tag = :query_title_for_observation
    #   @title_args[:observation] = obs.unique_format_name
    #   where << "field_slips.observation_id = '#{obs.id}'"
    # end

    def add_for_project_condition
      return if params[:project].blank?

      project = find_cached_parameter_instance(Project, :project)
      @title_tag = :query_title_for_project
      @title_args[:project] = project.title
      where << "field_slips.project_id = '#{project.id}'"
    end

    # def initialize_code_match_parameter
    #   return if params[:code].blank?

    #   add_exact_match_condition("field_slips.code", params[:code])
    # end

    def self.default_order
      "date"
    end
  end
end
