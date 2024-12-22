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
      add_owner_and_time_stamp_conditions
      add_by_user_condition
      add_for_project_condition
      super
    end

    def self.default_order
      "date"
    end
  end
end
