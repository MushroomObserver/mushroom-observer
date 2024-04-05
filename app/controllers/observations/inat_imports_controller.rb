# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
# (There is no corresponding InatImport model.)
module Observations
  class InatImportsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    def new; end

    def create
      return redirect_to(new_observation_path) if params[:inat_ids].blank?
      return reload_form if bad_inat_id_param?

      # TODO: Do I need timeout?
      # TODO: need error checking

      # How many responses?
      response =
        HTTParty.
        get(
          "https://api.inaturalist.org/v1/observations?" \
          "id=#{params[:inat_ids]}" \
          "&order=desc&order_by=created_at&only_id=true",
          format: :plain
        )
      json = JSON.parse(response, symbolize_names: true)

=begin from ProjectsController
      if title.blank?
        flash_error(:add_project_need_title.t)
      elsif project
        flash_error(:add_project_already_exists.t(title: project.title))
      elsif ProjectConstraints.new(params).ends_before_start?
        flash_error(:add_project_ends_before_start.t)
      elsif user_group
        flash_error(:add_project_group_exists.t(group: title))
      elsif admin_group
        flash_error(:add_project_group_exists.t(group: admin_name))
      else
        return create_project(title, admin_name, params[:project][:place_name])
      end
      @project = Project.new
      image_ivars
      render(:new, location: new_project_path(q: get_query_param))
=end

      # Etiher of these get iNat Obs
      # curl -X GET --header 'Accept: application/json' 'https://api.inaturalist.org/v1/observations?id=202555552'
      # https://api.inaturalist.org/v1/observations?id=202555552
    end

    # ---------------------------------

    private

    def reload_form
      @inat_ids = params[:inat_ids]
      render(:new)
    end

    def bad_inat_id_param?
      inat_id_array = params[:inat_ids].split
      # inat_id_array.none? ||
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
  end
end
