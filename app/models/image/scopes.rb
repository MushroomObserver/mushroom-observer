# frozen_string_literal: true

module Image::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do # rubocop:disable Metrics/BlockLength
    scope :index_order,
          -> { order(created_at: :desc, id: :desc) }

    scope :with_sizes, lambda { |min, max = min|
      if max == min
        with_min_size(min)
      else
        with_min_size(min).with_max_size(max)
      end
    }
    scope :with_min_size, lambda { |min|
      size = Image::ALL_SIZES_INDEX[min.to_sym]
      where(Image[:width].gteq(size).or(Image[:height].gteq(size)))
    }
    scope :with_max_size, lambda { |max|
      size = Image::ALL_SIZES_INDEX[max.to_sym]
      where(Image[:width].lt(size).or(Image[:height].lt(size)))
    }
    scope :with_content_types, lambda { |types|
      exts  = Image::ALL_EXTENSIONS.map(&:to_s)
      mimes = Image::ALL_CONTENT_TYPES.map(&:to_s).compact_blank
      types &= exts # intersection
      return if types.empty?

      other = types.include?("raw")
      types -= ["raw"]
      types = types.map { |x| mimes[exts.index(x)] }
      in_types = Image[:content_type].in(types)
      not_in_mimes = Image[:content_type].not_in(mimes)
      if types.empty?
        where(not_in_mimes)
      elsif other
        where(in_types.or(not_in_mimes))
      else
        where(in_types)
      end
    }

    scope :with_notes,
          -> { where(Image[:notes].coalesce("").length.gt(0)) }
    scope :without_notes,
          -> { where(Image[:notes].coalesce("").length.eq(0)) }
    scope :notes_contain,
          ->(phrase) { search_columns(Image[:notes], phrase) }
    scope :copyright_holder_contains,
          ->(phrase) { search_columns(Image[:copyright_holder], phrase) }

    # A search of all searchable Image fields, concatenated.
    scope :search_content,
          ->(phrase) { search_columns(Image.searchable_columns, phrase) }
    # Grabbing image ids from the Observation.includes is waay faster than
    # a 3x join from images to observation_images to observations to comments.
    # Advanced search scope. Does not check Name[:search_name] (author)
    scope :search_content_observation_and_comments, lambda { |phrase|
      obs_imgs = Observation.search_notes_and_comments(phrase).
                 includes(:images).map(&:images).flatten.uniq
      search_content(phrase).distinct.or(Image.where(id: obs_imgs).distinct)
    }
    # Pattern search scope. Excludes images without observations!
    scope :search_content_name_and_location, lambda { |phrase|
      cols = Image.searchable_columns + Observation[:where] + Name[:search_name]
      joins(observations: :name).search_columns(cols, phrase).distinct
    }

    scope :with_license,
          ->(license) { where(license: license) }
    scope :with_votes,
          -> { where(Image[:vote_cache].not_eq(nil)) }
    scope :without_votes,
          -> { where(Image[:vote_cache].eq(nil)) }
    scope :with_quality, lambda { |min, max = min|
      if max == min
        where(Image[:vote_cache].gteq(min))
      else
        where(Image[:vote_cache].gteq(min).and(Image[:vote_cache].lteq(max)))
      end
    }
    scope :with_confidence, lambda { |min, max = min|
      if max == min
        joins(:observations).where(Observation[:vote_cache].gteq(min))
      else
        joins(:observations).where(Observation[:vote_cache].gteq(min).
                                   and(Observation[:vote_cache].lteq(max)))
      end
    }
    scope :ok_for_export,
          -> { where(ok_for_export: true) }
    scope :not_ok_for_export,
          -> { where(ok_for_export: false) }

    scope :interactive_includes, lambda {
      strict_loading.includes(
        :image_votes, :license, :projects, :user
      )
    }
  end

  module ClassMethods
    # class methods here, `self` included
  end
end
