# frozen_string_literal: true

module Query
  module Initializers
    # initializing methods inherited by all Query's for Descriptions
    # currently only Names
    module Descriptions
      def descriptions_parameter_declarations
        {
          with_default_desc?: :boolean,
          join_desc?: { string: [:default, :any] },
          desc_type?: [{ string: [Description.all_source_types] }],
          desc_project?: [:string],
          desc_creator?: [User],
          desc_content?: :string,
          ok_for_export?: :boolean
        }
      end

      def descriptions_coercion_parameter_declarations
        {
          old_title?: :string,
          old_by?: :string,
          by_author?: User
        }
      end

      def initialize_description_parameters(type = :name)
        initialize_with_default_desc_parameter(type)
        initialize_join_desc_parameter(type)
        initialize_desc_type_parameter(type)
        initialize_desc_project_parameter(type)
        initialize_desc_creator_parameter(type)
        initialize_desc_content_parameter(type)
      end

      def initialize_with_default_desc_parameter(type)
        add_boolean_condition(
          "#{type}s.description_id IS NOT NULL",
          "#{type}s.description_id IS NULL",
          params[:with_default_desc]
        )
      end

      def initialize_join_desc_parameter(type)
        if params[:join_desc] == :default
          add_join(:"#{type}_descriptions.default")
        elsif any_param_desc_fields?
          add_join(:"#{type}_descriptions")
        end
      end

      def initialize_desc_type_parameter(type)
        add_indexed_enum_condition(
          "#{type}_descriptions.source_type",
          params[:desc_type],
          Description.all_source_types
        )
      end

      def initialize_desc_project_parameter(type)
        add_id_condition(
          "#{type}_descriptions.project_id",
          lookup_projects_by_name(params[:desc_project])
        )
      end

      def initialize_desc_creator_parameter(type)
        add_id_condition(
          "#{type}_descriptions.user_id",
          lookup_users_by_name(params[:desc_creator])
        )
      end

      def initialize_desc_content_parameter(type)
        model = "#{type}_descriptions".classify.constantize
        fields = model.all_note_fields
        fields = fields.map { |f| "COALESCE(#{type}_descriptions.#{f},'')" }
        fields = "CONCAT(#{fields.join(",")})"
        add_search_condition(fields, params[:desc_content])
      end
    end
  end
end
