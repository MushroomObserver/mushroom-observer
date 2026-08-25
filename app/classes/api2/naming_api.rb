# frozen_string_literal: true

class API2
  # API for Naming (identifications)
  class NamingAPI < ModelAPI
    def model
      Naming
    end

    def page_length_level
      :lightweight
    end

    def high_detail_includes
      [:name, :user]
    end

    def query_params
      {
        id_in_set: parse_array(:naming, :id, as: :id),
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        by_users: parse_array(:user, :user, help: :creator),
        observations: parse_array(:observation, :observation, as: :id,
                                                              help: 1),
        names: parse_array(:name, :name, as: :id, help: 1),
        confidence: parse_range(:confidence, :confidence)
      }
    end

    def create_params
      @vote = parse(:confidence, :vote, default: Vote.maximum_vote)
      @reasons = parse_naming_reasons!
      {
        observation: parse(:observation, :observation),
        name: parse(:name, :name)
      }
    end

    def validate_create_params!(params)
      raise(MissingParameter.new(:observation)) if params[:observation].blank?
      raise(MissingParameter.new(:name))        if params[:name].blank?
    end

    def before_create(params)
      naming = Naming.user_construct({ name: params[:name] },
                                     params[:observation], @user)
      naming.current_user = @user
      apply_reasons!(naming)
      naming.save
      return naming if naming.new_record?

      consensus = ::Observation::NamingConsensus.new(params[:observation])
      consensus.change_vote_with_log(naming, @vote)
      naming
    end

    def update_params
      @reasons = parse_naming_reasons!(prefix: "set_")
      {
        set_name: parse(:name, :set_name),
        set_vote: parse(:confidence, :set_vote)
      }
    end

    def validate_update_params!(params)
      return if params[:set_name] || params[:set_vote] || @reasons.compact.any?

      raise(MissingSetParameters.new)
    end

    def build_setter(params)
      lambda do |naming|
        if params[:set_name] || @reasons.compact.any?
          update_naming_fields(naming, params[:set_name])
        end
        update_naming_vote(naming, params[:set_vote]) if params[:set_vote]
        naming
      end
    end

    def build_deleter
      lambda do |naming|
        must_have_edit_permission!(naming)
        consensus = ::Observation::NamingConsensus.new(naming.observation)
        raise(NamingLocked.new(naming)) unless consensus.deletable?(naming)

        naming.current_user = @user
        naming.destroy!
      end
    end

    private

    def update_naming_fields(naming, new_name)
      must_have_edit_permission!(naming)
      consensus = ::Observation::NamingConsensus.new(naming.observation)
      raise(NamingLocked.new(naming)) unless consensus.editable?(naming)

      naming.current_user = @user
      consensus.clean_votes(naming, new_name, @user) if new_name
      apply_reasons!(naming)
      new_name ? naming.update_object(new_name, true) : naming.save!
    end

    def update_naming_vote(naming, value)
      consensus = ::Observation::NamingConsensus.new(naming.observation)
      consensus.change_vote(naming, value, @user)
    end

    def apply_reasons!(naming)
      naming.reasons_array.each do |reason|
        val = @reasons[reason.num]
        val.nil? ? reason.delete : (reason.notes = val)
      end
    end

    def parse_naming_reasons!(prefix: "")
      Naming::Reason.all_reasons.each_with_object({}) do |num, reasons|
        val = parse(:string, :"#{prefix}reason_#{num}")
        reasons[num] = (val == "." ? nil : val)
      end
    end
  end
end
