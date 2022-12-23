# frozen_string_literal: true

# Images::LicensesController
module Images
  class LicensesController < ApplicationController
    before_action :login_required

    # Linked from show_obs, account prefs tabs and section, acct profile
    # Tabular form that lets user change licenses of their images.  The table
    # groups all the images of a given copyright holder and license type into
    # a single row.  This lets you change all Rolf's licenses in one stroke.
    # Linked from: account/prefs
    # Inputs:
    #   params[:updates][n][:old_id]      (old license_id)
    #   params[:updates][n][:new_id]      (new license_id)
    #   params[:updates][n][:old_holder]  (old copyright holder)
    #   params[:updates][n][:new_holder]  (new copyright holder)
    # Outputs: @data
    #   @data[n]["copyright_holder"]  Person who actually holds copyright.
    #   @data[n]["license_count"]     Number of images this guy holds with
    #                                 this type of license.
    #   @data[n]["license_id"]        ID of current license.
    #   @data[n]["license_name"]      Name of current license.
    #   @data[n]["licenses"]          Options for select menu.
    # SQL result
    #  [{"license_count"=>10764, "copyright_holder"=>"Jason Hollinger",
    #    "license_id"=>3},
    #   {"license_count"=>4, "copyright_holder"=>"Alan Cressler",
    #    "license_id"=>3},
    #   {"license_count"=>1, "copyright_holder"=>"Tim Wheeler", "license_id"=>2}]

    # license_updater
    def edit
      # Gather data for form.

      # map(&:attributes) gives you a hash of your selects with their keys
      @data = Image.includes(:license).where(user_id: @user.id).
              select(Arel.star.count.as("license_count"),
                     :copyright_holder, :license_id).
              group(:copyright_holder, :license_id).
              map(&:attributes).map do |datum|
        next unless (license = License.safe_find(datum["license_id"].to_i))

        datum["license_name"] = license.display_name
        datum["licenses"]     = License.current_names_and_ids(license)
        datum.except!("id")
      end
    end

    # process_license_changes
    def update
      params[:updates].each_value do |row|
        next unless row_changed?(row)

        images_to_update = Image.where(
          user: @user, license: row[:old_id], copyright_holder: row[:old_holder]
        )
        update_licenses_history(images_to_update, row[:old_holder],
                                row[:old_id])

        # Update the license info in the images
        images_to_update.update_all(license_id: row[:new_id],
                                    copyright_holder: row[:new_holder])
      end
    end

    ############################################################################

    private # private methods used by license updater

    def row_changed?(row)
      row[:old_id] != row[:new_id] ||
        row[:old_holder] != row[:new_holder]
    end

    # Add license change records with a single insert to the db.
    # Otherwise updating would take too long for many (e.g. thousands) of images
    def update_licenses_history(images_to_update, old_holder, old_license_id)
      CopyrightChange.insert_all(
        images_to_update.map do |image|
          { user_id: @user.id,
            updated_at: Time.current,
            target_type: "Image",
            target_id: image.id,
            year: image.when.year,
            name: old_holder,
            license_id: old_license_id }
        end
      )
    end
  end
end
