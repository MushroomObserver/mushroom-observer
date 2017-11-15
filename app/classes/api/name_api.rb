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
      {
        rank:           parse(:enum, :set_rank, limit: Name.all_ranks),
        citation:       parse(:string, :set_citation),
        classification: parse(:string, :set_classification),
        notes:          parse(:string, :set_notes)
        # TODO: change spelling of name and/or author
        # TODO: mark name as misspelling
        # TODO: change synonymy
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
      save_names(names)
      name
    end

    def must_have_edit_permission!(_obj); end

    def delete
      raise NoMethodForAction.new("DELETE", action)
    end

    ############################################################################

    private

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

    def save_names(names)
      names.each do |name|
        name.save if name && name.new_record?
      end
    end

    def parse_misspellings
      parse(:enum, :misspellings, default: :no, limit: [:no, :either, :only])
    end
  end
end
