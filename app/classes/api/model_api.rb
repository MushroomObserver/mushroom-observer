# encoding: utf-8

class API
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
          setter.call(obj)
        rescue => e
          errors << e
        end
      end
    end

    def build_query
      params = query_params
      params.remove_nils!
      params.merge!(:by => :id)
      Query.lookup(model.name.to_sym, :all, params)
    end

    def build_object
      params = create_params
      validate_create_params!(params)
      done_parsing_parameters!
      obj = model.new(params)
      obj.save or raise CreateFailed.new(obj)
      after_create(obj) if respond_to? :after_create
      return obj
    end

    def build_setter
      params = update_params
      params.remove_nils!
      raise MissingSetParameters.new if params.empty?
      lambda do |obj|
        must_have_edit_permission!(obj)
        obj.update_attributes!(params)
      end
    end

    def build_deleter
      lambda do |obj|
        must_have_edit_permission!(obj)
        obj.destroy or raise DestroyFailed.new(obj)
      end
    end

    def must_have_read_permission!(obj)
      if obj.respond_to?(:is_reader?) and
         !obj.is_reader?(user)
        raise MustHaveViewPermission.new(obj)
      end
    end

    def must_have_edit_permission!(obj)
      if obj.respond_to?(:user_id) and
         user.id == obj.user_id
      elsif obj.respond_to?(:has_edit_permission?) and
            obj.has_edit_permission?(user)
      else
        raise MustHaveEditPermission.new(obj)
      end
    end

    # This is just here until the new version of Query comes on-line.
    # I don't see any reason for API to know anything about SQL or tables.
    def sql_id_condition
      result = nil
      if ids = parse_integer_ranges(:id)
        result = ids.map do |term|
          if term.is_a?(Range)
            "#{model.table_name}.id >= #{term.begin} AND " +
            "#{model.table_name}.id <= #{term.end}"
          else
            "#{model.table_name}.id = #{term}"
          end
        end.join(' OR ')
      end
      return result
    end
  end
end
