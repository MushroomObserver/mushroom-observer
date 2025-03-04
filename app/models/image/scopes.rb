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

    scope :size, lambda { |min, max = min|
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

    scope :has_notes, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(Image[:notes].coalesce("").length.gt(0))
      else
        has_no_notes
      end
    }
    scope :has_no_notes,
          -> { where(Image[:notes].coalesce("").length.eq(0)) }
    scope :notes_has,
          ->(phrase) { search_columns(Image[:notes], phrase) }
    scope :copyright_holder_has,
          ->(phrase) { search_columns(Image[:copyright_holder], phrase) }
    scope :with_license,
          ->(license) { where(license: license) }
    scope :ok_for_export, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(ok_for_export: true)
      else
        not_ok_for_export
      end
    }
    scope :not_ok_for_export,
          -> { where(ok_for_export: false) }

    # A search of all Image SEARCHABLE_FIELDS, concatenated.
    scope :search_content,
          ->(phrase) { search_columns(Image.searchable_columns, phrase) }
    # Grabbing image ids from the Observation.includes is waay faster than
    # a 3x join from images to observation_images to observations to comments.
    # Does not check Name[:search_name] (author)
    scope :advanced_search, lambda { |phrase|
      obs_imgs = Observation.advanced_search(phrase).
                 includes(:images).map(&:images).flatten.uniq
      search_content(phrase).distinct.or(Image.where(id: obs_imgs).distinct)
    }
    # Excludes images without observations!
    scope :pattern, lambda { |phrase|
      cols = Image.searchable_columns + Observation[:where] + Name[:search_name]
      joins(observations: :name).search_columns(cols, phrase).distinct
    }

    scope :has_votes, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(Image[:vote_cache].not_eq(nil))
      else
        has_no_votes
      end
    }
    scope :has_no_votes,
          -> { where(Image[:vote_cache].eq(nil)) }
    # quality is on a scale from 1.0 to 4.0
    scope :quality, lambda { |min, max = nil|
      min, max = min if min.is_a?(Array) && min.size == 2
      if max.nil? || max == min
        where(Image[:vote_cache].gteq(min))
      else
        where(Image[:vote_cache].gteq(min).and(Image[:vote_cache].lteq(max)))
      end
    }
    # relates to Observation confidence, not image votes. -3.0..3.0
    scope :confidence, lambda { |min, max = nil|
      joins(:observations).merge(Observation.confidence(min, max))
    }

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
