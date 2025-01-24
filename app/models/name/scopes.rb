# frozen_string_literal: true

module Name::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do # rubocop:disable Metrics/BlockLength
    # default ordering for index queries
    scope :index_order,
          -> { order(sort_name: :asc, id: :desc) }

    scope :of_lichens,
          -> { where(Name[:lifeform].matches("%lichen%")) }
    scope :not_lichens,
          -> { where(Name[:lifeform].does_not_match("% lichen %")) }
    scope :deprecated,
          -> { where(deprecated: true) }
    scope :not_deprecated,
          -> { where(deprecated: false) }
    scope :with_description,
          -> { with_correct_spelling.where.not(description_id: nil) }
    scope :without_description,
          -> { with_correct_spelling.where(description_id: nil) }
    # Names needing descriptions
    # In the template, order scope `description_needed` by most frequently used:
    #   Name.description_needed.group(:name_id).reorder(Arel.star.count.desc)
    scope :description_needed,
          -> { without_description.joins(:observations).distinct }
    scope :description_includes, lambda { |text|
      joins(:descriptions).where(description_notes_concats.matches("%#{text}%"))
    }
    scope :with_description_in_project, lambda { |project|
      joins(descriptions: :project).
        merge(NameDescription.where(project: project))
    }
    scope :with_description_created_by, lambda { |user|
      joins(:descriptions).merge(NameDescription.where(user: user))
    }
    scope :with_description_reviewed_by, lambda { |user|
      joins(:descriptions).merge(NameDescription.where(reviewer: user))
    }
    scope :with_description_of_type, lambda { |source|
      # Check that it's a valid source type (string enum value)
      return none if Description::ALL_SOURCE_TYPES.exclude?(source)

      joins(:descriptions).merge(NameDescription.where(source_type: source))
    }
    scope :with_description_classification_differing, lambda {
      joins(:description).
        where(rank: 0..Name.ranks[:Genus]).
        where(NameDescription[:classification].
              not_eq(Name[:classification])).
        where(NameDescription[:classification].not_blank)
    }

    ### Module Name::Spelling
    scope :with_correct_spelling,
          -> { where(correct_spelling_id: nil) }
    scope :with_incorrect_spelling,
          -> { where.not(correct_spelling_id: nil) }
    scope :with_self_referential_misspelling,
          -> { where(Name[:correct_spelling_id].eq(Name[:id])) }
    scope :with_synonyms,
          -> { where.not(synonym_id: nil) }
    scope :without_synonyms,
          -> { where(synonym_id: nil) }
    scope :ok_for_export,
          -> { where(ok_for_export: true) }

    ### Module Name::Taxonomy. Rank scopes take text values, e.g. "Genus"
    scope :with_rank,
          ->(rank) { where(rank: ranks[rank]) if rank }
    scope :with_rank_between, lambda { |min, max = min|
      return with_rank(min) if min == max

      where(Name[:rank].in(rank_range(min, max)))
    }
    scope :with_rank_below,
          ->(rank) {where(Name[:rank] < ranks[rank]) if rank }
    scope :with_rank_and_name_in_classification, lambda { |rank, text_name|
      where(Name[:classification].matches("%#{rank}: _#{text_name}_%"))
    }
    scope :with_rank_at_or_below_genus, lambda {
      where((Name[:rank] <= ranks[:Genus]).or(Name[:rank].eq(ranks[:Group])))
    }
    scope :with_rank_above_genus, lambda {
      where(Name[:rank] > ranks[:Genus]).
        where(Name[:rank].not_eq(ranks[:Group]))
    }
    scope :subtaxa_of_genus_or_below, lambda { |text_name|
      # Note small diff w :text_name_includes scope
      where(Name[:text_name].matches("#{text_name} %"))
    }
    scope :subtaxa_of, lambda { |name|
      if name.at_or_below_genus?
        # Subtaxa can be determined from the text_nam
        subtaxa_of_genus_or_below(name.text_name).
          with_correct_spelling
      else
        # Need to examine the classification strings
        with_rank_and_name_in_classification(name.rank, name.text_name).
          with_correct_spelling
      end
    }

    ### Pattern Search
    scope :include_synonyms_of, lambda { |name|
      where(id: name.synonyms.map(&:id)).with_correct_spelling
    }
    # alias of `include_subtaxa_of`
    scope :in_clade,
          ->(name) { include_subtaxa_of(name) }
    scope :include_subtaxa_of, lambda { |name|
      names = [name] + subtaxa_of(name)
      where(id: names.map(&:id)).with_correct_spelling
    }
    scope :include_subtaxa_above_genus,
          ->(name) { include_subtaxa_of(name).with_rank_above_genus }
    scope :text_name_includes,
          ->(text_name) {where(Name[:text_name].matches("%#{text_name}%")) }
    scope :with_classification,
          -> { where(Name[:classification].not_blank) }
    scope :without_classification,
          -> { where(Name[:classification].blank) }
    scope :classification_includes, lambda { |classification|
      where(Name[:classification].matches("%#{classification}%"))
    }
    scope :with_author,
          -> { where(Name[:author].not_blank) }
    scope :without_author,
          -> { where(Name[:author].blank) }
    scope :author_includes,
          ->(author) { where(Name[:author].matches("%#{author}%")) }
    scope :with_citation,
          -> { where(Name[:citation].not_blank) }
    scope :without_citation,
          -> { where(Name[:citation].blank) }
    scope :citation_includes,
          ->(citation) { where(Name[:citation].matches("%#{citation}%")) }
    scope :with_notes,
          -> { where(Name[:notes].not_blank) }
    scope :without_notes,
          -> { where(Name[:notes].blank) }
    scope :notes_include,
          ->(notes) {where(Name[:notes].matches("%#{notes}%")) }
    scope :with_comments,
          -> { joins(:comments).distinct }
    scope :without_comments,
          -> { where.not(id: with_comments) }
    scope :comments_include, lambda { |summary|
      joins(:comments).where(Comment[:summary].matches("%#{summary}%")).distinct
    }
    scope :on_species_list, lambda { |species_list|
      joins(observations: :species_lists).
        merge(SpeciesListObservation.where(species_list: species_list))
    }
    # Accepts region string, location_id, or Location instance
    scope :at_location, lambda { |location|
      case location
      when String # treat it as a region, not looking for all string matches
        joins(observations: :location).
          where(Location[:name].matches("%#{location}"))
      when Integer, Location
        joins(:observations).where(observations: { location: location })
      else
        none
      end
    }
    # Names with Observations whose lat/lon are in a box
    # Pass kwargs (:north, :south, :east, :west), any order
    scope :in_box, lambda { |**args|
      joins(:observations).merge(Observation.in_box(**args)).distinct
    }

    ### Specialized Scopes for Name::Create
    # Get list of Names that are potential matches when creating a new name.
    # Takes results of Name.parse_name.  Used by NameController#create_name.
    # Three cases:
    #
    #   1. group with author       - only accept exact matches
    #   2. nongroup with author    - match names with correct or no author
    #   3. any name without author - ignore authors when matching names
    #
    # If the user provides an author, but the only match has no author, then we
    # just need to add an author to the existing Name.  If the user didn't give
    # an author, but there are matches with an author, then it already exists
    # and we should just ignore the request.
    #
    scope :matching_desired_new_parsed_name, lambda { |parsed_name|
      if parsed_name.rank == "Group"
        where(search_name: parsed_name.search_name)
      elsif parsed_name.author.empty?
        where(text_name: parsed_name.text_name)
      else
        where(text_name: parsed_name.text_name).
          where(author: [parsed_name.author, ""])
      end
    }
    scope :show_includes, lambda {
      strict_loading.includes(
        { comments: :user },
        :correct_spelling,
        { description: [:authors, :reviewer] },
        { descriptions: [:authors, :editors, :reviewer, :writer_groups] },
        { interests: :user },
        :misspellings,
        # { namings: [:user] },
        # { observations: [:location, :thumb_image, :user] },
        :rss_log,
        { synonym: :names },
        :user,
        :versions
      )
    }
  end

  module ClassMethods
    # class methods here, `self` included
    def rank_range(min, max)
      all_ranks = Name.all_ranks
      a = all_ranks.index(min) || 0
      b = all_ranks.index(max) || (all_ranks.length - 1)
      a, b = b, a if a > b # reverse if wrong order
      all_ranks[a..b].map { |r| Name.ranks[r] } # values start at 1
    end

    def description_notes_concats
      fields = NameDescription::ALL_NOTE_FIELDS.dup
      starting = NameDescription[fields.shift].coalesce("")
      fields.reduce(starting) do |result, field|
        result + NameDescription[field].coalesce("")
      end
    end
  end
end
