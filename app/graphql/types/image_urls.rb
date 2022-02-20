# frozen_string_literal: true

module Types::ImageUrls
  include Types::BaseInterface
  description "Fields generating urls from image_id, thumb_image_id, etc"

  field :img_src_thumb, String, null: true
  field :img_src_sm, String, null: true
  field :img_src_med, String, null: true
  field :img_src_lg, String, null: true
  field :img_src_huge, String, null: true
  field :img_src_full, String, null: true

  def db_image_id
    case object
    when ::User
      object.image_id
    when ::Image
      object.id
    when ::Observation, ::GlossaryTerm
      object.thumb_image_id
    else
      raise("Unexpected Object: #{object.inspect}")
    end
  end

  def img_src_thumb
    Image.url(:thumbnail, db_image_id)
  end

  def img_src_sm
    Image.url(:small, db_image_id)
  end

  def img_src_med
    Image.url(:medium, db_image_id)
  end

  def img_src_lg
    Image.url(:large, db_image_id)
  end

  def img_src_huge
    Image.url(:huge, db_image_id)
  end

  def img_src_full
    Image.url(:full_size, db_image_id)
  end

  # Optional, see below
  definition_methods do
    # Optional: if this method is defined, it overrides `Schema.resolve_type`
    def resolve_type(object, context)
      # ...
    end
  end
end
