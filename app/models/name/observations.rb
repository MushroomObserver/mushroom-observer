# frozen_string_literal: true

class Name
  # The goal of this class is to reduce the number of repetitive queries
  # on the Name show page that counted the results for each variant of
  # "observations of this name". These each originally did separate queries.
  # This class instead does a single query for `@all` observations where
  # the name or its synonyms were proposed, and exposes methods that select
  # the variants from within those results. Those selections can then be
  # separately counted to show the number of results for each variant,
  # without intitiating any other queries.
  class Observations
    # attr_reader :with_images, :of_taxon_this_name, :of_taxon_other_names

    def initialize(name)
      @name = name
      @name_ids = name.synonym_ids
      @other_name_ids = name.other_synonym_ids
      @all = Observation.joins(:namings).
             where(namings: { name_id: @name_ids }).
             order(vote_cache: :desc).distinct
    end

    def of_taxon_this_name
      @all.select { |obs| obs&.name_id == @name.id }
    end

    def of_taxon_other_names
      @all.select { |obs| obs&.name_id.in?(@other_name_ids) }
    end

    def of_taxon_any_name
      @all.select { |obs| obs&.name_id.in?(@name_ids) }
    end

    def where_taxon_proposed
      @all.reject { |obs| obs&.name_id == @name.id }
    end

    def where_name_proposed
      @all
    end

    def with_images
      of_taxon_this_name.reject { |obs| obs&.thumb_image_id.nil? }
    end

    def best_images
      image_ids = with_images.take(6).map(&:thumb_image_id)
      # One new lookup for the images. Order these by image votes
      Image.interactive_includes.where(id: image_ids).order(vote_cache: :desc)
    end
  end
end
