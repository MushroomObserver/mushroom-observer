# frozen_string_literal: true

# Licenses that are available for Images and Descriptions
class LicensesController < AdminController
  before_action :login_required
  # FIXME: uncomment net line after implememting :destroy
  # before_action :store_location, except: :destroy
  # FIXME: uncomment net line after implememting :index
  # before_action :pass_query_params, except: :index

  def show
    return false unless (@license = find_or_goto_index(License, params[:id]))

    @canonical_url = license_url(@license.id)
  end
end
