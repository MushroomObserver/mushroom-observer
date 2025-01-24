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
      size = ALL_SIZES_INDEX[min.to_sym]
      where(Image[:width].gteq(size).or(Image[:height].gteq(size)))
    }
    scope :with_max_size, lambda { |max|
      size = ALL_SIZES_INDEX[max.to_sym]
      where(Image[:width].lt(size).or(Image[:height].lt(size)))
    }
    scope :with_content_types, lambda { |types|
      exts  = ALL_EXTENSIONS.map(&:to_s)
      mimes = ALL_CONTENT_TYPES.map(&:to_s).compact_blank
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

    scope :notes_contain,
          ->(phrase) { search_columns(Image[:notes], phrase) }
    scope :search_content_and_associations, lambda { |phrase|
      # This is waay faster than the 3x join
      # from images to observation_images to observations to comments.
      obs = Observation.search_content(phrase).includes(:images)
      imgs = obs.map(&:images).flatten.uniq

      notes_contain(phrase).distinct.or(Image.where(id: imgs).distinct)
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
