# frozen_string_literal: true

# Licenses that are available for Images and Descriptions
# NOTE: inherits from AdminController in order to limit actions to admins
# NOTE: for badges see, e.g., app/views/controllers/shared/_form_ccbysa30.erb
class LicensesController < AdminController
  before_action :store_location, except: :destroy
  before_action :pass_query_params, except: :index

  def index
    @objects = License.all
  end

  def show
    return false unless (@license = find_or_goto_index(License, params[:id]))

    @canonical_url = license_url(@license.id)
  end

  def new
    @license = License.new
  end

  def create
    @license = new_license_from_params

    # I can't get @license.validates :uniqueness to work properly
    # It creates errors for each attribute, even if only one is duplicated
    # and blanks all the attributes
    if @license.attribute_duplicated?
      flash_warning("Duplicate display_name, code, or url")
      return render(:new)
    end

    if @license.save
      flash_notice(
        :runtime_added_name.t(type: :license, value: @license.display_name)
      )
      redirect_to(license_path(@license.id))
    else
      @license.errors.full_messages.each { |msg| flash_warning(msg) }
      render(:new)
    end
  end

  def edit
    @license = find_or_goto_index(License, params[:id])
    @deprecated = @license.deprecated
  end

  def update
    @license = edited_license_from_params

    return no_changes unless @license.changed?
    return duplicate_attribute if @license.attribute_duplicated?

    if @license.save
      update_succeded
    else
      update_failed
    end
  end

  # NOTE: a callback prevents destruction of licenses that are in use
  def destroy
    if (@license = License.find(params[:id])) && @license.destroy
      flash_notice(:runtime_destroyed_id.t(type: :license, value: params[:id]))
    end
    redirect_to(licenses_path)
  end

  #########

  private

  def new_license_from_params
    license = License.new(license_params)
    add_deprecated(license)
  end

  def edited_license_from_params
    license = License.find(params[:id])
    license.display_name = params.dig(:license, :display_name)
    license.url = params.dig(:license, :url)
    add_deprecated(license)
  end

  def add_deprecated(license)
    license.deprecated = (params[:deprecated] == "1")
    license
  end

  def license_params
    params[:license].permit(:display_name, :url)
  end

  def no_changes
    flash_warning(:runtime_edit_name_no_change.l)
    render(:edit)
  end

  def duplicate_attribute
    flash_warning(:runtime_license_duplicate_attributed.l)
    render(:edit)
  end

  def update_succeded
    flash_notice(
      :runtime_updated_id.t(type: :license, value: @license.id)
    )
    redirect_to(license_path(@license.id))
  end

  def update_failed
    @license.errors.full_messages.each { |msg| flash_warning(msg) }
    render(:edit)
  end
end
