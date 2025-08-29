# frozen_string_literal: true

module Image::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do
    scope :order_by_default,
          -> { order_by(::Query::Images.default_order) }

    scope :sizes, lambda { |min, max = nil|
      min, max = min if min.is_a?(Array)
      if max
        min_size(min).max_size(max)
      else
        min_size(min)
      end
    }
    scope :min_size, lambda { |min|
      size = Image::ALL_SIZES_INDEX[min.to_sym]
      where(Image[:width].gteq(size).or(Image[:height].gteq(size)))
    }
    scope :max_size, lambda { |max|
      size = Image::ALL_SIZES_INDEX[max.to_sym]
      where(Image[:width].lt(size).or(Image[:height].lt(size)))
    }
    scope :content_types, lambda { |types|
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

    scope :has_notes,
          ->(bool = true) { not_blank_condition(Image[:notes], bool:) }
    scope :notes_has,
          ->(phrase) { search_columns(Image[:notes], phrase) }

    scope :copyright_holder_has,
          ->(phrase) { search_columns(Image[:copyright_holder], phrase) }
    scope :license,
          ->(license) { where(license: license) }
    scope :ok_for_export,
          ->(bool = true) { where(ok_for_export: bool) }

    scope :has_votes,
          ->(bool = true) { presence_condition(Image[:vote_cache], bool:) }
    # quality is on a scale from 1.0 to 4.0
    scope :quality, lambda { |min, max = nil|
      min, max = min if min.is_a?(Array)
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

    scope :has_observations, lambda { |bool = true|
      joined_relation_condition(:observation_images, bool:)
    }
    scope :observations, lambda { |obs|
      joins(:observation_images).
        where(observation_images: { observation: obs })
    }
    scope :locations, lambda { |locations|
      return none if locations.blank?

      joins(observation_images: :observation).
        merge(Observation.locations(locations)).distinct
    }
    scope :projects, lambda { |projects|
      ids = Lookup::Projects.new(projects).ids
      joins(:project_images).where(project_images: { project_id: ids })
    }
    scope :species_lists, lambda { |species_lists|
      ids = Lookup::SpeciesLists.new(species_lists).ids
      joins(observation_images: { observation: :species_list_observations }).
        where(species_list_observations: { species_list_id: ids })
    }

    # FOR FUTURE REFERENCE
    # A search of all Image SEARCHABLE_FIELDS, concatenated.
    # scope :search_content,
    #       ->(phrase) { search_columns(Image.searchable_columns, phrase) }
    # Grabbing image ids from the Observation.includes is waay faster than
    # a 3x join from images to observation_images to observations to comments.
    # Does not check Name[:search_name] (author)
    # scope :advanced_search, lambda { |phrase|
    #   obs_imgs = Observation.advanced_search(phrase).
    #              includes(:images).map(&:images).flatten.uniq
    #   search_content(phrase).distinct.or(Image.where(id: obs_imgs).distinct)
    # }

    # Excludes images without observations!
    scope :pattern, lambda { |phrase|
      cols = Image.searchable_columns + Observation[:where] + Name[:search_name]
      joins(observations: :name).search_columns(cols, phrase)
    }

    scope :observation_query, lambda { |hash|
      joins(:observations).subquery(:Observation, hash)
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
