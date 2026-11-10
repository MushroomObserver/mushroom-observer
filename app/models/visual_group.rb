# frozen_string_literal: true

class VisualGroup < AbstractModel
  has_many :visual_group_images, dependent: :destroy
  has_many :images, through: :visual_group_images
  belongs_to :visual_model

  validates :name, presence: {
    message: proc { :cannot_be_blank.t }
  }
  validates :name, format: {
    without: /\t/, message: proc { :cannot_include_tabs.t }
  }

  def image_count(status = true)
    return visual_group_images.count if status.nil? || status == "needs_review"

    if status && status != "excluded"
      return visual_group_images.where(included: true).count
    end

    visual_group_images.where(included: false).count
  end

  def add_initial_images
    image_ids_by_name_vote(name, 1.5).each do |row|
      VisualGroupImage.create!(visual_group: self,
                               image_id: row[0],
                               included: true)
    end
  end

  # Returns Name records, not strings, so callers can render each
  # one's stored display_name (bold/italic textile markup, author
  # trimmed per viewer pref) via Name#format_name(user) instead of
  # re-deriving formatting from a bare string.
  def distinct_names
    Name.joins(observations: { observation_images: :image }).
      merge(Image.visual_groups(self).visual_group_included(true)).
      distinct.order(Name[:text_name]).limit(10)
  end

  def included_image_ids
    visual_group_images.where(included: true).pluck(:image_id)
  end

  def merge(visual_group)
    Rails.logger.info { "Merging #{visual_group.name} into #{name}" }
    visual_group.visual_group_images.each do |vgi|
      if vgi.image_in_group?(id)
        Rails.logger.info { "Image #{vgi.image.id} already in #{name}" }
      else
        vgi.visual_group = self
        if vgi.save
          Rails.logger.info { "Moved #{vgi.image.id}" }
        else
          Rails.logger.info { "FAILED to move #{vgi.image.id}" }
          break
        end
      end
    end
  end

  private

  def image_ids_by_name_vote(name, vote)
    ObservationImage.joins({ observation: :name }).
      where(Observation[:vote_cache].gt(vote)).
      where(names: { text_name: name }).
      order(vote_cache: :desc).
      pluck(:image_id, :vote_cache)
  end
end
