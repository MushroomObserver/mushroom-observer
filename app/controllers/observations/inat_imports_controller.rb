# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
# (There is no corresponding InatImport model.)
module Observations
  class InatImportsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # FIXME: Get a key. This one belongs to @pellaea
    # The idea is having one key for all iNat imports
    INAT_IMPORT_KEY = APIKey.first

    def new; end

    def create
      inat_id_array = params[:inat_ids].split
      return redirect_to(new_observation_path) if params[:inat_ids].blank?
      return reload_form if bad_inat_ids_param?(inat_id_array)

      @user = User.current
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
      inat_obs = InatObs.new(imported_inat_obs_data)
      return not_importable(inat_obs) unless inat_obs.importable?

      @observation = Observation.new(
        when: inat_obs.when,
        where: inat_obs.where,
        lat: inat_obs.lat,
        lng: inat_obs.lng,
        gps_hidden: inat_obs.gps_hidden,
        name_id: inat_obs.name_id,
        text_name: inat_obs.text_name,
        notes: inat_obs.notes,
        source: "mo_inat_import",
        inat_id: inat_obs.inat_id
      )
      @observation.save
      @observation.log(:log_observation_created)

      add_inat_images(inat_obs.inat_obs_photos)
      # TODO: Other things done by Observations#create
      # save_everything_else(params.dig(:naming, :reasons))
      # strip_images! if @observation.gps_hidden
      # update_field_slip(@observation, params[:field_code])
      # flash_notice(:runtime_observation_success.t(id: @observation.id))
      add_inat_summmary_data(inat_obs)
    end

    def inat_search_observations(ids)
      operation = "/observations?id=#{ids}" \
                  "&order=desc&order_by=created_at&only_id=false"
      ::Inat.new(operation).body
    end

    def not_importable(inat_obs)
      unless inat_obs.taxon_importable?
        flash_error(:inat_taxon_not_importable.t(id: inat_obs.inat_id))
      end
    end

    def add_inat_images(inat_obs_photos)
      inat_obs_photos.each do |obs_photo|
        photo = InatObsPhoto.new(obs_photo)
        # ImageAPI#create params to consider adding to API params below
        # projects: parse_array(:project, :projects, must_be_member: true) ||
        #           [],
        params = {
          method: :post,
          action: :image,
          api_key: INAT_IMPORT_KEY.key,
          upload_url: photo.url,

          copyright_holder: photo.copyright_holder,
          license: photo.license_id,
          notes: photo.notes,
          original_name: photo.original_name
        }

        api = API2.execute(params)
        User.current = @user # API call zaps User.current

        image = Image.find(api.results.first.id)

        # Imaage attributes to potentially update manually
        # t.boolean "ok_for_export", default: true, null: false
        # t.boolean "gps_stripped", default: false, null: false
        # t.boolean "diagnostic", default: true, null: false
        image.update(
          user_id: User.current.id, # throws Error if done as API param above
          # TODO: get date from EXIF; it could be > obs date
          when: @observation.when # throws Error if done as API param above
        )
        @observation.add_image(image)
      end
    end

    def add_inat_summmary_data(inat_obs)
      data =
        "#{:USER.t}: #{inat_obs.inat_user_login}\n".
        concat("#{:OBSERVED.t}: #{inat_obs.when}\n").
        concat("#{:LAT_LON.t}: #{inat_obs.inat_location} " \
               "+/-#{inat_obs.inat_public_positional_accuracy} m\n").
        concat("#{:PLACE.t}: #{inat_obs.inat_place_guess}\n").
        concat("#{:ID.t}: #{inat_obs.inat_taxon_name}\n").
        concat("#{:DQA.t}: #{dqa(inat_obs.inat_quality_grade)}\n").
        concat("#{:ANNOTATIONS.t}: #{:UNDER_DEVELOPMENT.t}\n").
        concat("#{:PROJECTS.t}: #{inat_obs.inat_project_names}\n").
        concat("#{:SEQUENCES.t}: #{:UNDER_DEVELOPMENT.t}\n").
        concat("#{:OBSERVATION_FIELDS.t}: \n" \
               "#{obs_fields(inat_obs.inat_obs_fields)}\n").
        concat("#{:TAGS.t}: #{inat_obs.inat_tags.join(" ")}\n")

      params = {
        target: @observation,
        summary: "iNat Data #{@observation.created_at}",
        comment: data
      }

      Comment.create(params)
      # TODO: Insure Comment.user is webmaster (or other special-purpose user)
    end

    def dqa(dqa)
      case dqa
      when /research/
        "Research Grade"
      when /needs_id/
        "Needs ID"
      when /casual/
        "Casual"
      else
        "??"
      end
    end

    def obs_fields(fields)
      fields.map do |field|
        "&nbsp;&nbsp;#{field[:name]}: #{field[:value]}"
      end.join("\n")
    end
  end
end
