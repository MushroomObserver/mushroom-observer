# frozen_string_literal: true

module Names::Classification
  module SharedPrivateMethods
    private

    def find_name!
      @name = find_or_goto_index(Name, params[:id])
    end

    def make_sure_parent_higher_rank!(parent)
      parent_index = Name.rank_index(parent.rank)
      our_index = Name.rank_index(@name.rank)
      return true if our_index < parent_index

      rank = :"rank_#{@name.rank.to_s.downcase}"
      flash_error(:inherit_classification_parent_lower_rank.t(rank: rank))
      false
    end

    def make_sure_name_is_at_or_above_genus!(name)
      return true unless name.below_genus?

      flash_error("only works at or above genera!")
      redirect_with_query(name.show_link_args)
      false
    end

    def make_sure_name_is_genus!(name)
      return true if name.rank == "Genus"

      flash_error("only works on genera!")
      redirect_with_query(name.show_link_args)
      false
    end

    def make_sure_name_below_genus!(name)
      return true if name.below_genus?

      flash_error("only works on taxa below genus!")
      redirect_with_query(name.show_link_args)
      false
    end

    def make_sure_genus_has_classification!(name)
      return true if name.accepted_genus&.classification.present?

      flash_error(:edit_name_fill_in_classification_for_genus_first.t)
      redirect_with_query(name.show_link_args)
      false
    end

    def make_sure_parent_has_classification!(parent)
      return true if parent.classification.present?

      flash_error(
        :inherit_classification_parent_blank.t(parent: parent.search_name)
      )
      false
    end

    def validate_classification!
      cleaned = Name.validate_classification(@name.rank, @name.classification)
      @name.classification = cleaned
    rescue StandardError => e
      flash_error(e.to_s)
      false
    end

    def resolve_name!(in_str, chosen_id)
      @options = @message = nil
      return Name.find(chosen_id) if chosen_id.present?

      name = Name.find_by(search_name: in_str)
      return name if name

      matches = matching_names(in_str)
      if matches.empty?
        no_names_match(in_str)
      elsif matches.one?
        one_name_matches(matches)
      else
        multiple_names_match(matches)
      end
    end

    def matching_names(in_str)
      matches = Name.where(text_name: in_str).to_a
      matches.reject!(&:deprecated) unless matches.all?(&:deprecated)
      matches.reject!(&:is_misspelling?) unless matches.all?(&:is_misspelling?)
      matches.reject! { |n| n.classification.blank? } \
        unless matches.all? { |n| n.classification.blank? }
      matches
    end

    def no_names_match(in_str)
      matches = Name.suggest_alternate_spellings(in_str)
      if matches.any?
        @options = matches
        @message = :inherit_classification_alt_spellings
      else
        flash_error(:inherit_classification_no_matches.t)
      end
      nil
    end

    def one_name_matches(matches)
      name = matches.first
      name = name.correct_spelling if name.correct_spelling
      name
    end

    def multiple_names_match(matches)
      @options = matches
      @message = :inherit_classification_multiple_matches
      nil
    end
  end
end
