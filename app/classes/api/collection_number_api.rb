class API
  # API for CollectionNumber
  class CollectionNumberAPI < ModelAPI
    self.model = CollectionNumber

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :observations,
      :user
    ]

    def query_params
      {
        where:        sql_id_condition,
        created_at:   parse_range(:time, :created_at),
        updated_at:   parse_range(:time, :updated_at),
        users:        parse_array(:user, :user, help: :creator),
        observations: parse_array(:observation, :observation, as: :id),
        name:         parse(:string, :collector, help: 1),
        number:       parse(:string, :number, help: 1),
        name_has:     parse(:string, :collector_has, help: 1),
        number_has:   parse(:string, :number_has, help: 1)
      }
    end

    def create_params
      @observation = parse(:observation, :observation,
                           must_have_edit_permission: true)
      {
        name:   parse(:string, :collector, help: 1) || @user.legal_name,
        number: parse(:string, :number, help: 1),
        user:   @user
      }
    end

    def update_params
      @adds    = parse_array(:observation, :add_observation, help: 1)
      @removes = parse_array(:observation, :remove_observation, help: 1)
      {
        name:   parse(:string, :set_collector, not_blank: true, help: 1),
        number: parse(:string, :set_number, not_blank: true, help: 1)
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:observation) unless @observation
      raise MissingParameter.new(:number)      if params[:number].blank?
    end

    def validate_update_params!(params)
      return if params.any? || @adds || @removes
      raise MissingSetParameters.new
    end

    def before_create(params)
      obj = CollectionNumber.where(name: params[:name],
                                   number: params[:number]).first
      return nil unless obj
      obj.add_observation(@observation)
      obj
    end

    def after_create(obj)
      obj.add_observation(@observation)
    end

    def build_setter(params)
      lambda do |obj|
        must_have_edit_permission!(obj)
        add_observations(obj)
        return nil if remove_observations(obj)
        obj.attributes = params
        other_obj = lookup_matching_collection_number(obj)
        if other_obj && other_obj != obj
          merge_collection_numbers(obj, other_obj)
        else
          change_collection_number(obj)
        end
      end
    end

    def lookup_matching_collection_number(obj)
      CollectionNumber.where(name: obj.name, number: obj.number).first
    end

    def change_collection_number(obj)
      old_format_name = obj.format_name_was
      obj.save
      obj.change_corresponding_herbarium_records(old_format_name)
      obj
    end

    def merge_collection_numbers(this_obj, other_obj)
      old_format_name = this_obj.format_name_was
      this_obj.change_corresponding_herbarium_records(old_format_name)
      other_obj.observations += this_obj.observations - other_obj.observations
      this_obj.destroy
      other_obj
    end

    def add_observations(obj)
      return unless @adds
      @adds.each do |obs|
        raise MustHaveEditPermission.new(obj) unless obs.can_edit?(@user)
        obj.add_observation(obs)
      end
    end

    # Returns true if the collection_number is destroyed because it has no
    # more observations left.
    def remove_observations(obj)
      return false unless @removes
      @removes.each do |obs|
        obj.remove_observation(obs)
        return true unless obj.id
      end
      return false
    end
  end
end
