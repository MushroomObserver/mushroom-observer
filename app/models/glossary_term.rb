# frozen_string_literal: true

# Glossary of mycological terms, with illustrations.
#
# NOTE: Glossary terms are attached to one or more images via the glue table
# glossary_term_images.  This table includes the thumbnail!!!!
class GlossaryTerm < AbstractModel
  require "acts_as_versioned"

  belongs_to(:thumb_image,
             class_name: "Image",
             inverse_of: :thumb_glossary_terms)
  belongs_to :user
  belongs_to :rss_log

  has_many :glossary_term_images, dependent: :destroy
  has_many :images, through: :glossary_term_images

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
    "rss_log_id",
    "locked"
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

  def remove_image(image)
    images.delete(image) if images.member?(image)
    return unless thumb_image == image

    self.thumb_image = images.first
    save
  end

  def other_images
    images.where.not(id: thumb_image_id)
  end

  ##############################################################################

  private

  def must_have_description_or_image
    return if description.present? || thumb_image.present?

    errors.add(:base, :glossary_error_description_or_image.t)
  end
end
