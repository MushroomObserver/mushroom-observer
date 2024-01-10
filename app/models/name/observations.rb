# frozen_string_literal: true

class Name
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
      # One new lookup for the images.
      Image.interactive_includes.where(id: image_ids).order(vote_cache: :desc)
    end
  end
end
