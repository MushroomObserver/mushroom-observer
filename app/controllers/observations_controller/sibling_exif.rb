# frozen_string_literal: true

# Camera-info for an observation's occurrence sibling images -- images
# that belong to another member of the same occurrence (usually an iNat
# reflection). The edit form shows a read-only "Use this info" panel for
# each, so the editor can copy the reflection's location onto the native
# even though the reflection carries no editable image fields (#5317).
module ObservationsController::SiblingEXIF
  private

  # Keyed by image id; same shape as get_exif_data, plus :obscured
  # (iNat geoprivacy blurred the coordinates, so they are approximate).
  def sibling_exif_data
    return {} unless @observation.occurrence

    native_ids = @observation.image_ids
    sibling_members.each_with_object({}) do |member, data|
      member.images.each do |image|
        next if native_ids.include?(image.id)

        data[image.id] = member_camera_info(member, image)
      end
    end
  end

  def sibling_members
    @observation.occurrence.observations.
      where.not(id: @observation.id).includes(:images)
  end

  # lat/lng/alt to_f so the geocode JSON serializes as JS numbers -- the
  # form-exif controller calls `.toFixed` on them; a BigDecimal would
  # serialize as a quoted string and break that.
  def member_camera_info(member, image)
    {
      lat: member.lat&.to_f, lng: member.lng&.to_f, alt: member.alt&.to_f,
      date: member.when&.strftime("%d-%B-%Y"),
      file_name: image.original_name, obscured: member.gps_hidden
    }
  end
end
