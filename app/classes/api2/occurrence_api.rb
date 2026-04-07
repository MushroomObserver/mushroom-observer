# frozen_string_literal: true

class API2
  # API for Occurrence
  class OccurrenceAPI < ModelAPI
    def model
      Occurrence
    end

    def high_detail_includes
      [
        { observations: [:name, :location, :user, :thumb_image] },
        :field_slip,
        :user
      ]
    end

    def query_params
      {
        id_in_set: parse_array(:occurrence, :id, as: :id),
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        by_users: parse_array(:user, :user, help: :creator),
        observations: parse_array(:observation, :observation, as: :id),
        field_slips: parse_array(:field_slip, :field_slip, as: :id)
      }
    end

    def create_params
      @observation_ids = parse_array(:observation, :observation,
                                     as: :id)
      @primary_id = parse(:observation, :primary_observation, as: :id)
      {}
    end

    def validate_create_params!(_params)
      raise(MissingParameter.new(:observation)) if @observation_ids.blank?
      return unless @observation_ids.size < 2

      raise(BadParameterValue.new(@observation_ids.join(", "),
                                  :observation))
    end

    def before_create(_params)
      selected = Observation.where(id: @observation_ids).
                 includes({ occurrence: :field_slip }).to_a
      existing = selected.filter_map(&:occurrence).uniq
      Occurrence.check_multiple_occurrences!(existing)
      primary = resolve_primary(selected)
      Occurrence.create_manual(primary, selected, @user)
    end

    def update_params
      @add_obs = parse_array(:observation, :add_observation, as: :id)
      @remove_obs = parse_array(:observation, :remove_observation,
                                as: :id)
      @set_primary = parse(:observation, :set_primary_observation,
                           as: :id)
      {}
    end

    def validate_update_params!(_params)
      return if @add_obs || @remove_obs || @set_primary

      raise(MissingSetParameters.new)
    end

    def build_setter(_params)
      lambda do |occ|
        must_have_edit_permission!(occ)
        add_observations(occ)
        remove_observations(occ)
        return nil unless Occurrence.exists?(occ.id)

        update_primary(occ)
        occ.reload
        occ
      end
    end

    def build_deleter
      lambda do |occ|
        must_have_edit_permission!(occ)
        occ.dissolve!
        occ.destroyed? ? nil : occ
      end
    end

    private

    def resolve_primary(selected)
      if @primary_id
        selected.find { |o| o.id == @primary_id } || selected.first
      else
        selected.min_by(&:created_at)
      end
    end

    def add_observations(occ)
      return unless @add_obs

      obs_to_add = load_observations_to_add
      Occurrence.check_field_slip_conflicts!(
        occ.observations.to_a + obs_to_add
      )
      obs_to_add.each { |obs| add_one_observation(occ, obs) }
      occ.recompute_has_specimen!
    end

    def load_observations_to_add
      Observation.where(id: @add_obs).
        includes({ occurrence: :field_slip }).to_a
    end

    def add_one_observation(occ, obs)
      if obs.occurrence && obs.occurrence != occ
        Occurrence.merge!(occ, obs.occurrence)
      elsif obs.occurrence_id != occ.id
        obs.update!(occurrence: occ)
        Occurrence.log_observation_added([obs])
      end
    end

    def remove_observations(occ)
      return unless @remove_obs

      @remove_obs.each do |obs_id|
        obs = occ.observations.find_by(id: obs_id)
        next unless obs

        occ.reassign_thumbnails_from(obs)
        obs.update!(occurrence: nil)
        Occurrence.log_observation_removed(obs, occ)
      end
      occ.reload
      occ.destroy_if_incomplete!
    end

    def update_primary(occ)
      return unless @set_primary
      return unless occ.id # may have been destroyed

      occ.update!(primary_observation_id: @set_primary)
    end
  end
end
