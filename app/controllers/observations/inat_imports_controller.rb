# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
# (There is no corresponding InatImport model.)
module Observations
  class InatImportsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    def new; end

    def create
      inat_id_array = params[:inat_ids].split
      return redirect_to(new_observation_path) if params[:inat_ids].blank?
      return reload_form if bad_inat_ids_param?(inat_id_array)

      inat_id_array.each do |inat_obs_id|
        import_one_observation(inat_obs_id)
      end
    end

    # ---------------------------------

    private

    def reload_form
      @inat_ids = params[:inat_ids]
      render(:new)
    end

    def bad_inat_ids_param?(inat_id_array)
      multiple_ids?(inat_id_array) ||
        illegal_ids?(inat_id_array)
    end

    def multiple_ids?(inat_id_array)
      return false unless inat_id_array.many?

      flash_warning(:inat_not_single_id.l)
      true
    end

    def illegal_ids?(inat_id_array)
      illegal_ids = []
      inat_id_array.each do |id|
        next if /\A\d+\z/.match?(id)

        illegal_ids << id
        flash_warning(:runtime_illegal_inat_id.l(id: id))
      end
      illegal_ids.any?
    end

    def import_one_observation(inat_obs_id)
      imported_inat_obs_data = inat_search_observations(inat_obs_id)
      inat_obs = ImportedInatObs.new(imported_inat_obs_data)
    end

    INAT_API_BASE = "https://api.inaturalist.org/v1"

    def inat_search_observations(ids)
      operation = "/observations?id=#{ids}" \
                  "&order=desc&order_by=created_at&only_id=false"
      inat_search(operation).body
    end

    def inat_search(operation)
      HTTParty.get("#{INAT_API_BASE}#{operation}")
      # TODO: Do I need timeout?
      # TODO: need Error checking
      # TODO: Delay in order to limit rate?
    end
  end
end
