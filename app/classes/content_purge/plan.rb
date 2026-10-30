# frozen_string_literal: true

# What a ContentPurge removes (#5521), as relations rather than id lists:
# the largest holder has ~140k images.
#
# Images: for an MO user, the images they uploaded to MO; for anyone
# with an iNat login, the images imported from iNat whose copyright
# holder is that iNat user ("(c) <iNat name or login>, ..."). Imported
# images an MO user holds that are someone else's photos stay.
#
# Notes, like images, are content the holder could hold copyright in, so
# every MO-native observation of the MO user that has notes loses them
# and keeps the facts (date, location, collector, names).
#
# Observations that lose images:
#   - an imported observation left with no images becomes a placeholder,
#     as for an unlicensed iNat observation, and its notes are cleared;
#   - any other observation just loses the images.
class ContentPurge::Plan
  def initialize(target_user: nil, inat_login: nil)
    @target_user = target_user
    @inat_login = target_user ? target_user.inat_username : inat_login
  end

  def images
    @images ||= if @target_user
                  held_native_images.or(inat_images)
                else
                  inat_images
                end
  end

  def native_observations
    return Observation.none unless @target_user

    Observation.where(user: @target_user).has_notes.
      where.not(id: imported_observation_ids)
  end

  def placeholder_observations
    Observation.where(id: affected_observation_ids).
      where(id: imported_observation_ids).
      where.not(id: observations_keeping_an_image)
  end

  def image_count = images.count

  def native_observation_count = native_observations.count

  # The iNat names a holder can appear under: the login, and the
  # display name iNat shows when the user has set one.
  def inat_names
    return [] if @inat_login.blank?

    @inat_names ||= [@inat_login,
                     Inat::UserLookup.call(@inat_login)&.dig("name")].
                    compact_blank.uniq
  end

  private

  def held_native_images
    Image.where(user: @target_user).where.not(id: imported_image_ids)
  end

  def inat_images
    return Image.none if inat_names.empty?

    Image.where(id: inat_image_ids).where(copyrighted_by_inat_user)
  end

  def copyrighted_by_inat_user
    inat_names.map do |name|
      holder = "(c) #{name}"
      Image[:copyright_holder].eq(holder).or(
        Image[:copyright_holder].
          matches("#{ActiveRecord::Base.sanitize_sql_like(holder)},%")
      )
    end.reduce(:or)
  end

  def affected_observation_ids
    ObservationImage.where(image_id: images.select(:id)).
      select(:observation_id)
  end

  def observations_keeping_an_image
    ObservationImage.where(observation_id: affected_observation_ids).
      where.not(image_id: images.select(:id)).select(:observation_id)
  end

  def imported_image_ids
    ExternalLink.import.where(target_type: "Image").select(:target_id)
  end

  def inat_image_ids
    imported_image_ids.where(external_site: ExternalSite.inaturalist)
  end

  def imported_observation_ids
    ExternalLink.import.where(target_type: "Observation").select(:target_id)
  end
end
