# frozen_string_literal: true

# Licenses that are available for Images and Descriptions
class LicensesController < AdminController
  # FIXME: uncomment net line after implememting :destroy
  # before_action :store_location, except: :destroy
  # FIXME: uncomment net line after implememting :index
  # before_action :pass_query_params, except: :index

  def index
    @objects = License.all
  end

  def show
    return false unless (@license = find_or_goto_index(License, params[:id]))

    @canonical_url = license_url(@license.id)
  end

  def new
    # NOTE: 2025-05-26 jdc
    # Added url to avoid this Failure; I don't understand why it fails.
    # FAIL LicensesControllerTest#test_new (2.57s)
    #      Expected HTML to contain form that posts to </licenses>,
    #      but only # found these: </licenses/new>.
    @url = "/licenses"
  end
end
