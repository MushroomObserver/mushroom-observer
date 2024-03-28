# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
# (There is no corresponding InatImport model.)
module Observations
  class InatImportsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    def new; end

    def create
      inat_ids = params[:inat_ids].split
      illegal_ids = []
      inat_ids.each do |id|
        next if /\A\d+\z/.match?(id)

        illegal_ids << id
        flash_warning(:runtime_illegal_inat_id.l(id: id))
      end
      if illegal_ids.any?
        @inat_ids = params[:inat_ids]
        render(:new)
      end

      # Etiher of these get iNat Obs
      # curl -X GET --header 'Accept: application/json' 'https://api.inaturalist.org/v1/observations?id=202555552'
      # https://api.inaturalist.org/v1/observations?id=202555552
    end
  end
end
