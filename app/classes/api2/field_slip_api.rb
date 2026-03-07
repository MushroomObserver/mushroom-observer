# frozen_string_literal: true

class API2
  # API for FieldSlip
  class FieldSlipAPI < ModelAPI
    def model
      FieldSlip
    end

    def high_detail_includes
      [
        :observations,
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
      @create_observation = parse(:observation, :observation)
      {
        code: parse(:string, :code, not_blank: true, help: 1),
        project: parse(:project, :project),
        user: @user
      }
    end

    def update_params
      @update_observation = parse(:observation, :set_observation)
      {
        code: parse(:string, :set_code, not_blank: true, help: 1),
        project: parse(:project, :set_project)
      }
    end

    def validate_create_params!(params)
      raise(MissingParameter.new(:code)) if params[:code].blank?

      validate_unique_code!(params[:code])
    end

    def validate_update_params!(params)
      return if params.any? || @update_observation

      raise(MissingSetParameters.new)
    end

    def after_create(obj)
      obj.current_user = @user if obj.respond_to?(:current_user=)
      return unless @create_observation

      @create_observation.update!(field_slip: obj)
      obj.adopt_user_from(@create_observation)
    end

    def build_setter(params)
      lambda do |obj|
        must_have_edit_permission!(obj)

        if params[:code] && params[:code] != obj.code
          validate_unique_code!(params[:code], exclude: obj)
        end

        obj.current_user = @user if obj.respond_to?(:current_user=)
        obj.attributes = params
        obj.save!

        if @update_observation
          @update_observation.update!(field_slip: obj)
          obj.adopt_user_from(@update_observation)
        end

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
