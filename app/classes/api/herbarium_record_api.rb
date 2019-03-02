class API
  # API for HerbariumRecord
  class HerbariumRecordAPI < ModelAPI
    self.model = HerbariumRecord

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :observations,
      :herbarium,
      :user
    ]

    def query_params
      {
        where:                sql_id_condition,
        created_at:           parse_range(:time, :created_at),
        updated_at:           parse_range(:time, :updated_at),
        users:                parse_array(:user, :user, help: :creator),
        herbaria:             parse_array(:herbarium, :herbarium, as: :id),
        observations:         parse_array(:observation, :observation, as: :id),
        has_notes:            parse(:boolean, :has_notes),
        initial_det:          parse(:string, :initial_det, help: 1),
        accession_number:     parse(:string, :accession_number, help: 1),
        notes_has:            parse(:string, :notes_has, help: 1),
        initial_det_has:      parse(:string, :initial_det_has, help: 1),
        accession_number_has: parse(:string, :accession_number_has, help: 1)
      }
    end

    def create_params
      @observation = parse(:observation, :observation)
      {
        herbarium:        parse(:herbarium, :herbarium),
        initial_det:      parse(:string, :initial_det, help: 1),
        accession_number: parse(:string, :accession_number, help: 1),
        notes:            parse(:string, :notes),
        user:             @user
      }
    end

    def update_params
      @adds    = parse_array(:observation, :add_observation, help: 1)
      @removes = parse_array(:observation, :remove_observation, help: 1)
      {
        herbarium:        parse(:herbarium, :set_herbarium, not_blank: true),
        initial_det:      parse(:string,
                                :set_initial_det,
                                not_blank: true,
                                help: 1),
        accession_number: parse(:string, :set_accession_number,
                                not_blank: true,
                                help: 1),
        notes:            parse(:string, :set_notes)
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:observation) unless @observation
      raise MissingParameter.new(:herbarium)   unless params[:herbarium]

      make_sure_can_add_herbarium_record!(params)
      provide_default_label!(params)
    end

    def validate_update_params!(params)
      return if params.any? || @adds || @removes

      raise MissingSetParameters.new
    end

    def make_sure_can_add_herbarium_record!(params)
      return if @observation.can_edit?(@user)
      return if params[:herbarium].curator?(@user)

      raise CantAddHerbariumRecord.new
    end

    def provide_default_label!(params)
      provide_default_initial_determination!(params)
      provide_default_accession_number!(params)
    end

    def provide_default_initial_determination!(params)
      return if params[:initial_det].present?

      params[:initial_det] = @observation.name.text_name
    end

    def provide_default_accession_number!(params)
      return if params[:accession_number].present?

      params[:accession_number] =
        if @observation.collection_numbers.one?
          @observation.collection_numbers.first.format_name
        else
          "MO #{@observation.id}"
        end
    end

    def before_create(params)
      obj = HerbariumRecord.where(
        herbarium: params[:herbarium],
        accession_number: params[:accession_number]
      ).first
      return nil unless obj
      raise HerbariumRecordAlreadyExists.new(obj) unless obj.can_edit?(@user)

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
        remove_observations(obj)
        obj.attributes = params
        other_obj = lookup_matching_herbarium_record(obj)
        if other_obj && other_obj != obj
          merge_herbarium_records(obj, other_obj)
        else
          change_herbarium_record(obj)
        end
      end
    end

    def must_have_edit_permission!(obj)
      return true if obj.can_edit?(@user) ||
                     obj.herbarium.curator?(@user)

      raise MustHaveEditPermission.new(obj)
    end

    def lookup_matching_herbarium_record(obj)
      HerbariumRecord.where(herbarium: obj.herbarium,
                            accession_number: obj.accession_number).first
    end

    def change_herbarium_record(obj)
      old_herbarium_id = obj.herbarium_id_was
      obj.save
      obj.notify_curators if obj.herbarium_id != old_herbarium_id
      obj
    end

    def merge_herbarium_records(this_obj, other_obj)
      raise HerbariumRecordAlreadyExists.new(this_obj)
    end

    def add_observations(obj)
      return unless @adds

      @adds.each do |obs|
        raise MustHaveEditPermission.new(obj) \
          unless obs.can_edit?(@user) || obj.herbarium.curator?(@user)

        obj.add_observation(obs)
      end
    end

    def remove_observations(obj)
      return unless @removes

      @removes.each do |obs|
        obj.remove_observation(obs)
      end
    end
  end
end
