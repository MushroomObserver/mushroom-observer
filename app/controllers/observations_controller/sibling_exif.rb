# frozen_string_literal: true

# Camera-info for the edit form's occurrence-sibling images -- images
# on a read-only iNat reflection member of the occurrence. The panel is
# read-only: it shows the image's immutable metadata (date, copyright,
# license) and a link to the source observation, and reads the image's
# EXIF for location (iNat usually strips it). "Use this info" is offered
# only when there is a location or a differing date to adopt onto the
# primary (#5317).
module ObservationsController::SiblingEXIF
  private

  # Keyed by image id: the image's EXIF (get_exif_data shape) merged
  # with the read-only reflection metadata the panel displays.
  def sibling_exif_data
    by_member = sibling_images_by_member
    return {} if by_member.empty?

    exif = get_exif_data(by_member.keys)
    by_member.each_with_object({}) do |(image, member), data|
      data[image.id] = exif[image.id].merge(reflection_meta(member, image))
    end
  end

  # { image => owning reflection member } for sibling images (leaving
  # out the primary's images), de-duplicated by image id.
  def sibling_images_by_member
    native_ids = @observation.image_ids.to_set
    seen = Set.new
    map = {}
    sibling_members.each do |member|
      collect_member_images(member, native_ids, seen, map)
    end
    map
  end

  def sibling_members
    return [] unless @observation.occurrence

    # Preload what the read-only panel reads per member/image: the
    # image license, and the import external link + its site for the
    # source URL -- otherwise N+1 per sibling image (#5317 review).
    @observation.occurrence.observations.
      where.not(id: @observation.id).
      includes(images: :license, external_links: :external_site)
  end

  def collect_member_images(member, native_ids, seen, map)
    member.images.each do |image|
      next if native_ids.include?(image.id) || !seen.add?(image.id)

      map[image] = member
    end
  end

  def reflection_meta(member, image)
    {
      read_only: true,
      copyright_holder: image.copyright_holder,
      license_name: image.license&.display_name,
      source_url: reflection_source_url(member),
      date_differs: image.when != @observation.when
    }
  end

  # The reflection's source-observation URL, built from its external
  # link's id and the site's URL template (nil when absent).
  # The reflection's iNat source URL, from its import link (external_id
  # must be present -- ExternalLink allows it blank, and "" is truthy).
  def reflection_source_url(member)
    link = member.import_link
    return nil if link&.external_id.blank?

    link.external_site.observation_url(link.external_id)
  end
end
