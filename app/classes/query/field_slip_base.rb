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
        project?: Project
      )
    end

    def initialize_flavor
      add_owner_and_time_stamp_conditions("field_slips")
      add_by_user_condition("field_slips")
      add_for_project_condition
      super
    end

    def add_for_project_condition
      return if params[:project].blank?

      project = find_cached_parameter_instance(Project, :project)
      @title_tag = :query_title_for_project
      @title_args[:project] = project.title
      where << "field_slips.project_id = '#{project.id}'"
    end

    def self.default_order
      "date"
    end
  end
end
