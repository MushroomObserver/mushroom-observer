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

      redirect_to(observations_path)
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
      xlated_inat_obs = Observation.new(
        when: inat_obs.when,
        where: inat_obs.where,
        lat: inat_obs.lat,
        lng: inat_obs.lng,
        gps_hidden: inat_obs.gps_hidden,
        name_id: inat_obs.name_id,
        text_name: inat_obs.text_name,
        notes: inat_obs.notes
      )
      xlated_inat_obs.save
      xlated_inat_obs.log(:log_observation_created)

      @observation = xlated_inat_obs

      add_inat_images(inat_obs.obs_photos)
      # TODO: Other things done by Observations#create
      # save_everything_else(params.dig(:naming, :reasons))
      # strip_images! if @observation.gps_hidden
      # update_field_slip(@observation, params[:field_code])
      # flash_notice(:runtime_observation_success.t(id: @observation.id))
    end

    def inat_search_observations(ids)
      operation = "/observations?id=#{ids}" \
                  "&order=desc&order_by=created_at&only_id=false"
      inat_search(operation).body
    end

    # TODO: move to own class so it can be called from multiple places
    INAT_API_BASE = "https://api.inaturalist.org/v1"

    def inat_search(operation)
      HTTParty.get("#{INAT_API_BASE}#{operation}")
      # TODO: Do I need timeout?
      # TODO: need Error checking
      # TODO: Delay in order to limit rate?
    end

    def add_inat_images(obs_photos)
      obs_photos.each do |obs_photo|
        photo = InatObsPhoto.new(obs_photo)
        # FIXME: Get a key. This one belongs to @pellaea
        api_key = APIKey.first

        params = {
          method: :post,
          action: :image,
          api_key: api_key.key,
          upload_url: photo.url
        }

        # FIXME: Why does API2.execute(params) return nil?
        # Need to get the id of the image which it creates
        api = API2.execute(params)

        # FIXME: Need to get the ID of the image I just added
        # instead of whatever image someone happened to have added last
        # see prior FIXME
        @observation.add_image(Image.last)
      end
    end
  end
end
