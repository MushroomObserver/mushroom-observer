# frozen_string_literal: true

# Who else loses an image in an ImagePurge, and what (#5521): the owners
# of observations, glossary terms and projects that show one of the
# purged images, apart from the purge's target. Visual groups have no
# owner, so nobody is told about them.
class ImagePurge::Notices
  INAT_PHOTO_URL = "#{Inat::Constants::SITE}/photos/".freeze

  # content: [[label, url], ...] the receiver owns that showed the image.
  # source_url: where the photo can still be seen (iNat), or nil for a
  # photo uploaded to MO.
  Entry = Data.define(:image_id, :copyright_holder, :content, :source_url)

  def initialize(plan, target_user: nil)
    @plan = plan
    @target_user = target_user
  end

  # {receiver User => [Entry, ...]}
  def by_receiver
    content = owned_content
    images = by_id(Image, content.keys.map(&:last))
    receivers = by_id(User, content.keys.map(&:first))
    content.each_with_object({}) do |((user_id, image_id), items), result|
      next unless (receiver = receivers[user_id])

      (result[receiver] ||= []) << entry(images[image_id], items)
    end
  end

  private

  def by_id(model, ids) = model.where(id: ids.uniq).index_by(&:id)

  # {[owner id, image id] => [[label, url], ...]}
  def owned_content
    content = Hash.new { |hash, key| hash[key] = [] }
    content_rows.each do |user_id, image_id, item|
      next if user_id.nil? || user_id == @target_user&.id

      content[[user_id, image_id]] << item
    end
    content
  end

  def content_rows
    observation_rows + glossary_term_rows + project_rows
  end

  def observation_rows
    Observation.joins(:observation_images).
      where(observation_images: { image_id: image_ids }).
      pluck(:user_id, ObservationImage[:image_id], :id).
      map do |user_id, image_id, id|
        [user_id, image_id,
         ["#{:observation.ti} #{id}", Observation.show_url(id)]]
      end
  end

  def glossary_term_rows
    GlossaryTerm.joins(:glossary_term_images).
      where(glossary_term_images: { image_id: image_ids }).
      pluck(:user_id, GlossaryTermImage[:image_id], :id, :name).
      map do |user_id, image_id, id, name|
        [user_id, image_id, [name, GlossaryTerm.show_url(id)]]
      end
  end

  def project_rows
    Project.joins(:project_images).
      where(project_images: { image_id: image_ids }).
      pluck(:user_id, ProjectImage[:image_id], :id, :title).
      map do |user_id, image_id, id, title|
        [user_id, image_id, [title, Project.show_url(id)]]
      end
  end

  def image_ids
    @plan.images.select(:id)
  end

  def entry(image, items)
    Entry.new(image_id: image.id, copyright_holder: image.copyright_holder,
              content: items.uniq, source_url: source_url(image))
  end

  # The iNat observation the photo was imported with, else the iNat
  # photo page; nil for a photo uploaded to MO.
  def source_url(image)
    photo_link = image.import_link
    return nil unless photo_link&.inaturalist_id

    observation_link = ExternalLink.import.
                       where(target_type: "Observation",
                             target_id: ObservationImage.
                               where(image_id: image.id).
                               select(:observation_id)).
                       first
    observation_link&.link_url || "#{INAT_PHOTO_URL}#{photo_link.external_id}"
  end
end
