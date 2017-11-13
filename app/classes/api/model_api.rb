# API
class API
  # API subclass for all model-based endpoints
  class ModelAPI < API
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

    def put
      must_authenticate!
      self.query = build_query
      setter = build_setter
      done_parsing_parameters!
      abort_if_any_errors!
      results.each do |obj|
        begin
          setter.call(obj)
        rescue => e
          errors << e
        end
      end
    end

    def delete
      must_authenticate!
      self.query = build_query
      deleter = build_deleter
      done_parsing_parameters!
      abort_if_any_errors!
      results.each do |obj|
        begin
          deleter.call(obj)
        rescue => e
          errors << e
        end
      end
    end

    def build_query
      params = query_params
      params.remove_nils!
      params[:by] = :id
      Query.lookup(model.name.to_sym, query_flavor, params)
    rescue RuntimeError => e
      raise QueryError.new(e)
    end

    def query_flavor
      :all
    end

    def build_object
      params = create_params
      validate_create_params!(params)
      done_parsing_parameters!
      before_create
      obj = model.new(params)
      obj.save || raise(CreateFailed.new(obj))
      after_create(obj)
      obj
    end

    # Stub for validating parameters before actually creating the object.
    def validate_create_params!(params); end

    # Stub for hook before creating object.
    def before_create; end

    # Stub for hook after creating object.
    def after_create(obj); end

    def build_setter
      params = update_params
      params.remove_nils!
      raise MissingSetParameters.new if params.empty?
      lambda do |obj|
        must_have_edit_permission!(obj)
        obj.update!(params)
      end
    end

    def build_deleter
      lambda do |obj|
        must_have_edit_permission!(obj)
        obj.destroy || raise(DestroyFailed.new(obj))
      end
    end

    def must_have_read_permission!(obj)
      if obj.respond_to?(:is_reader?) &&
         !obj.is_reader?(user)
        raise MustHaveViewPermission.new(obj)
      end
    end

    def must_have_edit_permission!(obj)
      if obj.respond_to?(:user_id) &&
         user.id == obj.user_id
      elsif obj.respond_to?(:has_edit_permission?) &&
            obj.has_edit_permission?(user)
      else
        raise MustHaveEditPermission.new(obj)
      end
    end

    def model_tag
      self.class.model.type_tag
    end

    # This is just here until the new version of Query comes on-line.
    # I don't see any reason for API to know anything about SQL or tables.
    def sql_id_condition
      ids = parse_integer_ranges(:id)
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
