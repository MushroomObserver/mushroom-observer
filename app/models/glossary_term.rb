# frozen_string_literal: true

# Glossary of mycological terms, with illustrations
class GlossaryTerm < AbstractModel
  require "acts_as_versioned"

  belongs_to(:thumb_image,
             class_name: "Image",
             foreign_key: "thumb_image_id",
             inverse_of: :best_glossary_terms)
  belongs_to :user
  belongs_to :rss_log
  has_and_belongs_to_many :images, -> { order "vote_cache DESC" }

  validates :name, presence: {
    message: proc { :glossary_error_name_blank.t }
  }
  # rubocop:disable Rails/UniqueValidationWithoutIndex
  # It's not worth indexing :name in the db;
  # Uniqueness of this attribute is nice, but not critical
  validates :name, uniqueness: {
    case_sensitive: false,
    message: proc { :glossary_error_duplicate_name.t }
  }
  # rubocop:enable Rails/UniqueValidationWithoutIndex
  validate :must_have_description_or_image

  after_destroy(:destroy_unused_images)

  ALL_TERM_FIELDS = [:name, :description].freeze
  acts_as_versioned(
    table_name: "glossary_terms_versions",
    if_changed: ALL_TERM_FIELDS,
    association_options: { dependent: :nullify }
  )
  non_versioned_columns.push(
    "thumb_image_id",
    "created_at",
    "updated_at",
    "rss_log_id"
  )
  versioned_class.before_save { |x| x.user_id = User.current_id }

  # Automatically log standard events.
  self.autolog_events = [:created!, :updated!, :destroyed!]

  # Probably should add a user_id and a log
  # versioned_class.before_save {|x| x.user_id = User.current_id}

  def text_name
    name
  end

  def format_name
    name
  end

  def unique_format_name
    unique_text_name
  end

  def unique_text_name
    "#{name} (#{id})"
  end

  def can_edit?(_user = User.current)
    true
  end

  def add_image(image)
    return false unless image
    return false if images.include?(image)

    self.thumb_image = image if thumb_image.nil?
    images.push(image)
  end

  def all_images
    [thumb_image] + images
  end

  def remove_image(image)
    if images.member?(image)
      images.delete(image)
      save
    end

    return unless thumb_image == image

    new_thumb = images[0]
    self.thumb_image = images[0]
    images.delete(new_thumb) if new_thumb
    save
  end

  ##############################################################################

  private

  def must_have_description_or_image
    return if description.present? || thumb_image.present?

    errors[:base] << :glossary_error_description_or_image.t
  end

  def destroy_unused_images
    all_images.each do |image|
      image.destroy if image && !image.other_subjects?(self)
    end
  end
end
