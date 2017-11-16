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
        where:              sql_id_condition,
        created_at:         parse_range(:time, :created_at),
        updated_at:         parse_range(:time, :updated_at),
        users:              parse_array(:user, :user),
        names:              parse_array(:string, :name),
        synonym_names:      parse_array(:string, :synonyms_of),
        children_names:     parse_array(:string, :children_of),
        is_deprecated:      parse(:boolean, :is_deprecated),
        misspellings:       parse_misspellings,
        has_synonyms:       parse(:boolean, :has_synonyms),
        locations:          parse_array(:string, :location),
        species_lists:      parse_array(:string, :species_lists),
        rank:               parse(:enum, :rank, limit: Name.all_ranks),
        has_author:         parse(:boolean, :has_author),
        has_citation:       parse(:boolean, :has_citation),
        has_classification: parse(:boolean, :has_classification),
        has_notes:          parse(:boolean, :has_notes),
        has_comments:       parse(:boolean, :has_comments, limit: true),
        has_default_desc:   parse(:boolean, :has_description),
        text_name_has:      parse(:string, :text_name_has),
        author_has:         parse(:string, :author_has),
        citation_has:       parse(:string, :citation_has),
        classification_has: parse(:string, :classification_has),
        notes_has:          parse(:string, :notes_has),
        comments_has:       parse(:string, :comments_has),
        ok_for_export:      parse(:boolean, :ok_for_export)
      }
    end
    # rubocop:enable Metrics/AbcSize

    def create_params
      {
        rank:           parse(:enum, :rank, limit: Name.all_ranks),
        citation:       parse(:string, :citation, default: ""),
        deprecated:     parse(:boolean, :deprecated, default: false),
        classification: parse(:string, :classification, default: ""),
        notes:          parse(:string, :notes, default: "")
      }
    end

    def update_params
      parse_set_name!
      parse_set_synonymy!
      {
        notes:          parse(:string, :set_notes),
        citation:       parse(:string, :set_citation),
        classification: parse(:string, :set_classification)
      }
    end

    def build_object
      params   = create_params
      name_str = parse(:string, :name, limit: 100)
      author   = parse(:string, :author, limit: 100)
      done_parsing_parameters!
      raise MissingParameter.new(:name_str) if name_str.blank?
      raise MissingParameter.new(:rank)     if rank.blank?
      name_str2   = make_sure_name_doesnt_exist!(name_str, author)
      name, names = make_sure_name_parses!(name_str2)
      fill_in_attributes(name, params, name_str, author)
      save_new_names(names)
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
      end
    end

    def validate_update_params!(params)
      @classification = params[:classification]
      validate_classification!(params)
      raise MissingSetParameters.new if params.empty?
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

    def must_be_creator!(name)
      return if name.user == @user
      raise MustBeCreator.new(type: :name)
    end

    def must_be_only_editor!(name)
      return unless name.versions.any? { |x| x.user_id != @user.id }
      raise MustBeOnlyEditor.new(type: :name)
    end

    def must_own_all_descriptions!(name)
      return unless name.descriptions.any? { |x| x.user != @user }
      raise MustOwnAllDescriptions.new(type: :name)
    end

    def must_own_all_observations!(name)
      return unless name.observations.any? { |x| x.user != @user }
      raise MustOwnAllObservations.new(type: :name)
    end

    def must_own_all_namings!(name)
      return unless name.namings.any? { |x| x.user != @user }
      raise MustOwnAllNamings.new(type: :name)
    end

    def validate_classification!(params)
      return unless @classification
      params[:classification] = \
        Name.validate_classification(:Genus, @classification)
    rescue RuntimeError => e
      raise BadClassification.new
    end

    def make_sure_name_doesnt_exist!(name_str, author)
      match = nil
      if author.blank?
        match = Name.find_by_text_name(name_str)
        name_str2 = name_str
      else
        match = Name.find_by_text_name_and_author(name_str, author)
        name_str2 = "#{name_str} #{author}"
      end
      raise NameAlreadyExists.new(name_str, match) if match
      name_str2
    end

    def make_sure_name_parses!(name_str2)
      names = Name.find_or_create_name_and_parents(name_str2)
      name  = names.last
      raise NameDoesntParse.new(name_str2) if name.nil?
      [name, names]
    end

    def fill_in_attributes(name, params, name_str, author)
      name.attributes = params
      name.change_text_name(name_str, author, name.rank)
      name.change_deprecated(true) if name.deprecated
    end

    def save_new_names(names)
      names.each do |name|
        name.save if name && name.new_record?
      end
    end

    def parse_misspellings
      parse(:enum, :misspellings, default: :no, limit: [:no, :either, :only])
    end

    def parse_set_name!
      @name_str = parse(:string, :name, limit: 100)
      @author   = parse(:string, :author, limit: 100)
      @rank     = parse(:enum, :rank, limit: Name.all_ranks)
      return unless @name_str || @author || @rank
      return if query.num_results == 0
      raise TryingToSetMultipleNamesAtOnce.new if query.num_results > 1
    end

    def parse_set_synonymy!
      @deprecated      = parse(:boolean, :set_deprecated)
      @synonymize_with = parse(:name, :synonymize_with)
      @clear_synonyms  = parse(:boolean, :clear_synonyms, limit: [true])
      raise OneOrTheOther.new(:synonymize_with, :clear_synonyms) \
        if @synonymize_with && @clear_synonyms
    end

    def change_name(name)
      return unless @name_str || @author || @rank
      @name_str ||= name.text_name
      @author   ||= name.author
      @rank     ||= name.rank
      name.change_text_name(@name_str, @author, @rank, :save_parents)
    end

    def change_deprecated(name)
      return if @deprecated.nil?
      name.change_deprecated(@deprecated)
    end

    def add_synonym(name)
      return unless @synonymize_with
      raise CanOnlySynonymizeUnsynonimizedNames.new if name.synonym
      name.merge_synonyms(@synonymize_with)
    end

    def clear_synonymy(name)
      return unless @clear_synonyms
      name.clear_synonym
    end
  end
end
