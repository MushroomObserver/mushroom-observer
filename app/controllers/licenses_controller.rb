# frozen_string_literal: true

# Licenses that are available for Images and Descriptions
# available only to admins (because of class inheritance)
class LicensesController < AdminController
  # FIXME: uncomment next line after implememting :destroy
  # before_action :store_location, except: :destroy
  # FIXME: uncomment next line after implememting :index
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

  def create
    @license = License.new(
      display_name: params[:display_name],
      form_name: params[:form_name],
      url: params[:url],
      deprecated: (params[:deprecated] == "true")
    )

    if @license.save
      redirect_to(license_path(@license.id))
    else
      render(:new)
    end
  end

  def edit
    @license = find_or_goto_index(License, params[:id])
  end

  def update
    @license = License.find(params[:id])

    @license.display_name = params.dig(:license, :display_name)
    @license.form_name = params.dig(:license, :form_name)
    @license.url = params.dig(:license, :url)
    @license.deprecated = (params.dig(:license, :deprecated) == "true")

    save_any_changes
    redirect_to(license_path(@license.id))
  end

  #########

  private

  def save_any_changes
    if @license.changed?
      raise(:runtime_unable_to_save_changes.t) unless @license.save

      flash_notice(:runtime_updated_id.t(type: "License", id: @license.id))
    else
      flash_warning(:runtime_no_changes.t)
    end
  end
end
