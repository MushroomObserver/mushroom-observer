# frozen_string_literal: true

# List of image URLa for updating the images in MO's MyCoPortal database
# via MyCoPortal's Occurence Management, Observation Project Management,
#    Administration Control Panel. Processing Toolbox
# MCP expects a CSV with one row per image and 2 columns: catalogNumber, imageId
module Report
  class MycoportalImageList < CSV
    attr_accessor :query

    # This URL prefix is permanent for large images, should always be correct,
    # no matter how much we change the underlying image server(s).
    # It should be the same in all environments, so that we can use the dev
    # environment for MyCoPortal uploads.
    LARGE_IMG_PERMALINK_PREFIX = "https://mushroomobserver.org/images/1280/"

    def initialize(query)
      super
      @query = query[:query]
    end

    # --------------------
    # Things expected by Observation::DownloadsController#render_report.

    def body
      image_list
    end

    def mime_type
      "text/csv"
    end

    def encoding
      "UTF-8"
    end

    def filename
      "mycoportal_image_list_#{@query.id&.alphabetize}.csv"
    end

    def header
      { header: :present }
    end

    # --------------------

    # Records every image included in the most recent #body call as
    # exported to MyCoPortal, so future calls skip it (avoids sending
    # images MCP already has, which it doesn't dedupe on its end).
    # A separate step from #body/#image_list -- not automatic -- so
    # merely computing a CSV never has the side effect of marking
    # images as sent; only an explicit post-generation call does.
    def mark_exported!
      unless @exported_image_ids
        raise("mark_exported! called before body/image_list")
      end

      site = ExternalSite.mycoportal
      @exported_image_ids.each { |image_id| create_export_link(site, image_id) }
    end

    # --------------------

    private

    def image_list
      rows_data = image_rows_data
      @exported_image_ids = rows_data.pluck(1).uniq

      ::CSV.generate(col_sep: ",", encoding: "UTF-8") do |csv|
        csv << %w[catalogNumber imageId rights]
        rows_data.each do |row|
          csv << formatted_row(row)
        end
      end
    end

    def image_rows_data
      Image.joins(:observations, :user, :license).
        where(observations: { id: @query.result_ids }).
        where.not(id: already_exported_image_ids).
        # MCP doesn't care about order, but our tests do.
        order(observation_id: :asc, id: :asc).
        pluck(:observation_id, :id,
              Image[:copyright_holder],
              User[:name], User[:login], License[:url])
    end

    # Images already exported to MyCoPortal (any prior run, or the
    # one-time DwC-A backfill) -- excluded so MCP never receives a
    # duplicate media record for the same image.
    def already_exported_image_ids
      ExternalLink.where(external_site: ExternalSite.mycoportal,
                         target_type: "Image", relationship: :export).
        select(:target_id)
    end

    def create_export_link(site, image_id)
      return if ExternalLink.exists?(target_type: "Image",
                                     target_id: image_id,
                                     external_site: site,
                                     relationship: :export)

      ExternalLink.create!(user: User.admin, target_type: "Image",
                           target_id: image_id, external_site: site,
                           relationship: :export)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(
        "Mycoportal export link failed for Image #{image_id}: #{e.message}"
      )
    end

    def formatted_row(row)
      obs_id, image_id, copyright_holder, user_name, user_login, license_url =
        row
      [catalog_number(obs_id), large_image_url(image_id),
       rights(copyright_holder, user_name, user_login, license_url)]
    end

    def rights(copyright_holder, user_name, user_login, license_url)
      name = copyright_holder.presence ||
             unique_text_name(user_name, user_login)
      License.rights_string(name, license_url)
    end

    def unique_text_name(name, login)
      name.blank? ? login : "#{name} (#{login})"
    end

    def catalog_number(observation_id)
      "MUOB #{observation_id}"
    end

    def large_image_url(image_id)
      "#{LARGE_IMG_PERMALINK_PREFIX}#{image_id}.jpg"
    end
  end
end
