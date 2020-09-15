# frozen_string_literal: true

class API
  # API subclass for all model-based endpoints
  class ModelAPI < API
    def model_tag
      self.class.model.type_tag
    end

    def get
      self.query = build_query
      done_parsing_parameters!
    end

    def post
      must_authenticate!
      object = build_object
      @results = [object]
      @result_ids = [object.id]
    end

    def patch
      must_authenticate!
      self.query = build_query
      update_objects
    end

    def delete
      must_authenticate!
      self.query = build_query
      delete_objects
    end

    ############################################################################

    protected

    def build_query
      params = query_params
      params.remove_nils!
      params[:by] = :id
      Query.lookup(model.name.to_sym, query_flavor, params)
    rescue RuntimeError => e
      raise(QueryError.new(e))
    end

    def query_flavor
      :all
    end

    # Stub for parsing and validating params passed to Query.
    def query_params
      raise("missing query_params stub!")
    end

    # ----------------------------------------

    def build_object
      params = create_params
      done_parsing_parameters!
      validate_create_params!(params)
      obj = before_create(params) ||
            model.create(params)
      raise(CreateFailed.new(obj)) if obj.new_record?

      after_create(obj)
      obj
    end

    # Stub for parsing and validating attributes passed to Model.create.
    def create_params
      raise("missing create_params stub!")
    end

    # Stub for validating parameters before actually creating the object.
    def validate_create_params!(params); end

    # Stub for hook before creating object.  Return an object instance if the
    # object already exists and you don't want to create a new object.
    def before_create(_params)
      nil
    end

    # Stub for hook after creating object.
    def after_create(obj); end

    # ----------------------------------------

    def update_objects
      mark_the_rest_as_set_params
      params = update_params
      params.remove_nils!
      done_parsing_parameters!
      validate_update_params!(params)
      setter = build_setter(params)
      abort_if_any_errors!
      results.map! do |obj|
        setter.call(obj)
      rescue StandardError => e
        errors << e
        nil
      end.reject!(&:nil?)
    end

    # Stub for parsing and validating attributes to pass to record.update.
    def update_params
      raise("missing update_params stub!")
    end

    def validate_update_params!(params)
      raise(MissingSetParameters.new) if params.empty?
    end

    def build_setter(params)
      lambda do |obj|
        must_have_edit_permission!(obj)
        obj.update!(params)
        obj
      end
    end

    # ----------------------------------------

    def delete_objects
      done_parsing_parameters!
      deleter = build_deleter
      abort_if_any_errors!
      results.each do |obj|
        deleter.call(obj)
      rescue StandardError => e
        errors << e
      end
    end

    def build_deleter
      lambda do |obj|
        must_have_edit_permission!(obj)
        obj.destroy!
      end
    end

    # ----------------------------------------

    def must_have_view_permission!(obj)
      if obj.respond_to?(:is_reader?) &&
         !obj.is_reader?(user)
        raise(MustHaveViewPermission.new(obj))
      end
    end

    def must_have_edit_permission!(obj)
      unless (obj.respond_to?(:user_id) && user.id == obj.user_id) ||
             (obj.respond_to?(:can_edit?) && obj.can_edit?(user))
        raise(MustHaveEditPermission.new(obj))
      end
    end

    def must_have_delete_permission!(obj)
      must_have_edit_permission!(obj)
    end

    # This is just here until the new version of Query comes on-line.
    # I don't see any reason for API to know anything about SQL or tables.
    def sql_id_condition
      ids = parse_ranges(:integer, :id)
      return nil unless ids

      ids.map do |term|
        if term.is_a?(Range)
          "#{model.table_name}.id >= #{term.begin} AND " \
          "#{model.table_name}.id <= #{term.end}"
        else
          "#{model.table_name}.id = #{term}"
        end
      end.join(" OR ")
    end
  end
end
