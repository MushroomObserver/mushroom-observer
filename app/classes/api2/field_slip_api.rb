# frozen_string_literal: true

class API2
  # API for FieldSlip
  class FieldSlipAPI < ModelAPI
    def model
      FieldSlip
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
        :observation,
        :project,
        :user
      ]
    end

    def query_params
      {
        id_in_set: parse_array(:field_slip, :id, as: :id),
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        by_users: parse_array(:user, :user, help: :creator),
        code: parse(:string, :code, help: 1),
        code_has: parse(:string, :code_has, help: 1),
        observation: parse(:observation, :observation),
        project: parse(:project, :project)
      }
    end

    def create_params
      {
        code: parse(:string, :code, not_blank: true, help: 1),
        observation: parse(:observation, :observation),
        project: parse(:project, :project),
        user: @user
      }
    end

    def update_params
      {
        code: parse(:string, :set_code, not_blank: true, help: 1),
        observation: parse(:observation, :set_observation),
        project: parse(:project, :set_project)
      }
    end

    def validate_create_params!(params)
      raise(MissingParameter.new(:code)) if params[:code].blank?

      validate_unique_code!(params[:code])
    end

    def validate_update_params!(params)
      return if params.any?

      raise(MissingSetParameters.new)
    end

    def before_create(params)
      # Check if field slip with this code already exists
      FieldSlip.find_by(code: params[:code])
    end

    def after_create(obj)
      # Set current_user for permission checks in model
      obj.current_user = @user if obj.respond_to?(:current_user=)
    end

    def build_setter(params)
      lambda do |obj|
        must_have_edit_permission!(obj)

        # Validate code uniqueness if being changed
        if params[:code] && params[:code] != obj.code
          validate_unique_code!(params[:code], exclude: obj)
        end

        # Set current_user for permission checks in model
        obj.current_user = @user if obj.respond_to?(:current_user=)

        obj.attributes = params
        obj.save
        obj
      end
    end

    def must_have_edit_permission!(obj)
      return if obj.can_edit?(@user)

      raise(MustHaveEditPermission.new(obj))
    end

    def validate_unique_code!(code, exclude: nil)
      existing = FieldSlip.find_by(code: code)
      return unless existing && existing != exclude

      raise(CodeAlreadyUsed.new(code))
    end

    # Error class for duplicate code
    class CodeAlreadyUsed < API2::Error
      def initialize(code)
        super()
        @code = code
      end

      def to_s
        "Field slip code '#{@code}' is already in use."
      end
    end
  end
end
