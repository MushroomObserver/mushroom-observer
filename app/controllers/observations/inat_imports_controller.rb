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

      # Find out how many responses?
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

=begin
# params
{"utf8"=>"✓",
 "authenticity_token"=>"[FILTERED]",
 "observation"=>
  {"when(3i)"=>"23",
   "when(2i)"=>"3",
   "when(1i)"=>"2023",
   "place_name"=>"Cochise Co., Arizona, USA",
   "is_collection_location"=>"1",
   "lat"=>"31.8813",
   "long"=>"-109.244",
   "alt"=>"1942",
   "gps_hidden"=>"0",
   "specimen"=>"0",
   "notes"=>
    {"Preliminary_Identification"=>"",
     "Collection_#"=>"",
     "Collector"=>"",
     "Identifier"=>"",
     "Habitat"=>"",
     "Substrate"=>"",
     "Nearest_Tree(s)"=>"",
     "Habit"=>"",
     "Taste"=>"",
     "Odor"=>"",
     "Micro"=>"",
     "Other"=>"on Quercus\r\n\r\n&#8212;\r\n\r\nMirrored on iNaturalist as <a href=\"https://www.inaturalist.org/observations/202555552\">observation 202555552</a> on March 15, 2024."},
   "thumb_image_id"=>"1659475",
   "log_change"=>"1"},
 "good_image"=>
  {"1659475"=>{"notes"=>"", "original_name"=>"CB0CFD21-8F52-4E04-A732-73CA6A22FFF9.jpg", "copyright_holder"=>"Joseph D. Cohen", "when(3i)"=>"23", "when(2i)"=>"3", "when(1i)"=>"2023"},
   "license_id"=>"2",
   "1659476"=>{"notes"=>"", "original_name"=>"E46F88A5-6BF1-41AF-8512-F27A50263F64.jpg", "copyright_holder"=>"Joseph D. Cohen", "when(3i)"=>"23", "when(2i)"=>"3", "when(1i)"=>"2023"},
   "1659477"=>{"notes"=>"", "original_name"=>"6973487B-FE88-41CB-B23B-0EE81D03DB43.jpg", "copyright_holder"=>"Joseph D. Cohen", "when(3i)"=>"23", "when(2i)"=>"3", "when(1i)"=>"2023"},
   "1659478"=>{"notes"=>"", "original_name"=>"F33A7074-4CEC-4347-BCFD-5E11FC3CE031.jpg", "copyright_holder"=>"Joseph D. Cohen", "when(3i)"=>"23", "when(2i)"=>"3", "when(1i)"=>"2023"},
   "1659479"=>{"notes"=>"", "original_name"=>"30CFDBE5-6C47-484C-A464-B56E29234AB4.jpg", "copyright_holder"=>"Joseph D. Cohen", "when(3i)"=>"23", "when(2i)"=>"3", "when(1i)"=>"2023"}},
 "good_images"=>"1659475 1659476 1659477 1659478 1659479",
 "project"=>{"id_342"=>"0", "id_336"=>"0", "id_213"=>"0", "id_168"=>"0", "id_306"=>"0", "id_200"=>"0", "id_337"=>"0"},
 "list"=>
  {"id_433"=>"0",
   "id_673"=>"0",
   "id_650"=>"0",
   "id_559"=>"0",
   "id_800"=>"0",
   "id_868"=>"0",
   "id_880"=>"0",
   "id_974"=>"0",
   "id_525"=>"0",
   "id_1611"=>"0",
   "id_956"=>"0",
   "id_863"=>"0",
   "id_1547"=>"0",
   "id_873"=>"0",
   "id_859"=>"0",
   "id_939"=>"0",
   "id_970"=>"0",
   "id_1058"=>"0",
   "id_1017"=>"0",
   "id_1218"=>"0",
   "id_2244"=>"0"},
 "id"=>"547126"}
=end

    def import_one_observation
      response =
        HTTParty.
        get(
          "https://api.inaturalist.org/v1/observations?" \
          "id=#{params[:inat_ids]}" \
          "&order=desc&order_by=created_at&only_id=false",
          format: :plain
        )

      debugger
      json = JSON.parse(response, symbolize_names: true)


      params = {}

      redirect_to(new_observation_path)

    end
  end
end
