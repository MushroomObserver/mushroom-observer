# frozen_string_literal: true

class API
  # API for Name
  class NameAPI < ModelAPI
    self.model = Name

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :comments,
      { synonym: :names }
    ]

    # rubocop:disable Metrics/AbcSize
    def query_params
      {
        where: sql_id_condition,
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        users: parse_array(:user, :user, help: :first_user),
        names: parse_array(:name, :name, as: :id),
        is_deprecated: parse(:boolean, :is_deprecated),
        misspellings: parse_misspellings,
        has_synonyms: parse(:boolean, :has_synonyms),
        locations: parse_array(:string, :location),
        species_lists: parse_array(:string, :species_list),
        rank: parse(:enum, :rank, limit: Name.all_ranks),
        has_author: parse(:boolean, :has_author),
        has_citation: parse(:boolean, :has_citation),
        has_classification: parse(:boolean, :has_classification),
        has_notes: parse(:boolean, :has_notes),
        has_comments: parse(:boolean, :has_comments, limit: true),
        has_default_desc: parse(:boolean, :has_description),
        text_name_has: parse(:string, :text_name_has, help: 1),
        author_has: parse(:string, :author_has, help: 1),
        citation_has: parse(:string, :citation_has, help: 1),
        classification_has: parse(:string, :classification_has, help: 1),
        notes_has: parse(:string, :notes_has, help: 1),
        comments_has: parse(:string, :comments_has, help: 1),
        ok_for_export: parse(:boolean, :ok_for_export)
      }.merge(parse_names_parameters)
    end
    # rubocop:enable Metrics/AbcSize

    def create_params
      {
        citation: parse(:string, :citation, default: ""),
        classification: parse(:string, :classification, default: ""),
        notes: parse(:string, :notes, default: ""),
        user: @user
      }
    end

    def update_params
      parse_set_name!
      parse_set_synonymy!
      {
        notes: parse(:string, :set_notes),
        citation: parse(:string, :set_citation),
        classification: parse(:string, :set_classification)
      }
    end

    def build_object
      params = create_params
      parse_name_author_rank_deprecated
      done_parsing_parameters!
      validate_create_parameters!(params)
      parse = make_sure_name_parses!
      make_sure_name_doesnt_exist!(parse)
      name = create_name(parse, params)
      save_parents(parse)
      name
    end

    def build_setter(params)
      lambda do |name|
        must_have_edit_permission!(name)
        # Must re-check classification for each name, ranks may differ.
        validate_classification!(params)
        name.update(params)
        change_name(name)
        change_deprecated(name)
        name.save!
        add_synonym(name)
        clear_synonymy(name)
        change_correct_spelling(name)
        name
      end
    end

    def validate_create_parameters!(params)
      raise MissingParameter.new(:name) if @name.blank?
      raise MissingParameter.new(:rank) if @rank.blank?

      @classification = params[:classification]
      validate_classification!(params)
    end

    def validate_update_params!(params)
      @classification = params[:classification]
      validate_classification!(params)
      raise MissingSetParameters.new if params.empty? && no_other_update_params?
    end

    def delete
      raise NoMethodForAction.new("DELETE", action)
    end

    # Our restrictions on edit permissions for the API are much more strict
    # than on the website.  Revoke permission if anyone other than the creator
    # owns any attached objects: name versions, descriptions, observations
    # or name proposals.
    def must_have_edit_permission!(name)
      must_be_creator!(name)
      must_be_only_editor!(name)
      must_own_all_descriptions!(name)
      must_own_all_observations!(name)
      must_own_all_namings!(name)
    end

    ############################################################################

    private

    def parse_misspellings
      parse(:enum, :misspellings, default: :no, limit: [:no, :either, :only],
                                  help: 1)
    end

    def validate_classification!(params)
      return unless @classification

      params[:classification] = \
        Name.validate_classification(:Genus, @classification)
    rescue RuntimeError
      raise BadClassification.new
    end

    # ----------------------------------------

    def parse_name_author_rank_deprecated
      @name       = parse(:string, :name, limit: 100)
      @author     = parse(:string, :author, limit: 100)
      @rank       = parse(:enum, :rank, limit: Name.all_ranks)
      @deprecated = parse(:boolean, :deprecated, default: false)
    end

    def make_sure_name_parses!
      str   = Name.clean_incoming_string("#{@name} #{@author}")
      parse = Name.parse_name(str, rank: @rank, deprecated: @deprecated)
      raise NameDoesntParse.new(@name)         unless parse
      raise NameWrongForRank.new(@name, @rank) if parse.rank != @rank

      parse
    end

    def make_sure_name_doesnt_exist!(parse)
      match = Name.where(text_name: parse.text_name)
      return if match.none?
      return unless parse.author.blank? ||
                    match.any? { |n| n.author.blank? } ||
                    match.any? { |n| n.author == parse.author }

      raise NameAlreadyExists.new(parse.search_name)
    end

    def create_name(parse, params)
      params = params.merge(parse.params).merge(deprecated: @deprecated)
      name = Name.new(params)
      name.save || raise(CreateFailed.new(name))
      name
    end

    def save_parents(parse)
      return unless parse.parent_name

      parents = Name.find_or_create_name_and_parents(parse.parent_name)
      parents.each { |n| n.save if n&.new_record? }
    end

    # ----------------------------------------

    def must_be_creator!(name)
      return if name.user == @user

      raise MustBeCreator.new(:name)
    end

    def must_be_only_editor!(name)
      return unless name.versions.any? { |x| x.user_id != @user.id }

      raise MustBeOnlyEditor.new(:name)
    end

    def must_own_all_descriptions!(name)
      return unless name.descriptions.any? { |x| x.user != @user }

      raise MustOwnAllDescriptions.new(:name)
    end

    def must_own_all_observations!(name)
      return unless name.observations.any? { |x| x.user != @user }

      raise MustOwnAllObservations.new(:name)
    end

    def must_own_all_namings!(name)
      return unless name.namings.any? { |x| x.user != @user }

      raise MustOwnAllNamings.new(:name)
    end

    def parse_set_name!
      @name   = parse(:string, :set_name, limit: 100)
      @author = parse(:string, :set_author, limit: 100)
      @rank   = parse(:enum, :set_rank, limit: Name.all_ranks)
      return unless @name || @author || @rank
      return if query.num_results < 2

      raise TryingToSetMultipleNamesAtOnce.new
    end

    def parse_set_synonymy!
      @deprecated       = parse(:boolean, :set_deprecated)
      @synonymize_with  = parse(:name, :synonymize_with)
      @clear_synonyms   = parse(:boolean, :clear_synonyms, limit: true, help: 1)
      @correct_spelling = parse(:name, :set_correct_spelling, help: 1)
      return if (@synonymize_with ? 1 : 0) +
                (@clear_synonyms ? 1 : 0) +
                (@set_correct_spelling ? 1 : 0) <= 1

      raise OneOrTheOther.new([:synonymize_with, :clear_synonyms,
                               :set_correct_spelling])
    end

    # Disable cop because there's no reasonable way to avoid the offense
    # rubocop:disable Metrics/CyclomaticComplexity
    def no_other_update_params?
      !@name && !@author && !@rank && @deprecated.nil? &&
        !@synonymize_with && !@clear_synonyms && !@correct_spelling
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def change_name(name)
      return unless @name || @author || @rank

      @name   ||= name.text_name
      @author ||= name.author
      @rank   ||= name.rank
      name.change_text_name(@name, @author, @rank, :save_parents)
    end

    def change_deprecated(name)
      return if @deprecated.nil?

      name.change_deprecated(@deprecated)
    end

    def add_synonym(name)
      return unless @synonymize_with
      raise CanOnlySynonymizeUnsynonimizedNames.new if name.synonym_id

      name.merge_synonyms(@synonymize_with)
    end

    def clear_synonymy(name)
      return unless @clear_synonyms

      name.clear_synonym
    end

    def change_correct_spelling(name)
      return unless @correct_spelling
      return if name.correct_spelling_id == @correct_spelling.id
      raise CanOnlySynonymizeUnsynonimizedNames.new \
        if name.synonym_id && name_synonym_id != @correct_spelling.synonym_id

      name.change_deprecated(true) unless name.deprecated
      name.correct_spelling = @correct_spelling
      name.merge_synonyms(@correct_spelling)
      name.save
    end
  end
end
