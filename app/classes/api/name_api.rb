# encoding: utf-8

class API
  class NameAPI < ModelAPI
    self.model = Name

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :comments,
      { :synonym => :names },
    ]

    def query_params
      {
        :where              => sql_id_condition,
        :created            => parse_time_ranges(:created),
        :modified           => parse_time_ranges(:modified),
        :users              => parse_users(:user),
        :synonym_names      => parse_names(:synonyms_of),
        :children_names     => parse_names(:children_of),
        :is_deprecated      => parse_boolean(:is_deprecated) == true ? :yes : nil,
        :not_deprecated     => parse_boolean(:is_deprecated) == false ? :yes : nil,
        :is_misspelled      => parse_boolean(:is_misspelled) == true ? :yes : nil,
        :not_misspelled     => parse_boolean(:is_misspelled) == false ? :yes : nil,
        :has_synonyms       => parse_boolean(:has_synonyms),
        :locations          => parse_locations(:location),
        :species_lists      => parse_species_lists(:species_lists),
        :rank               => parse_enum_ranges(:rank, :limit => Name.all_ranks),
        :text_name_has      => parse_strings(:text_name_has),
        :has_author         => parse_boolean(:has_author),
        :author_has         => parse_strings(:author_has),
        :has_citation       => parse_boolean(:has_citation),
        :citation_has       => parse_strings(:citation_has),
        :has_classification => parse_boolean(:has_classification),
        :classification_has => parse_strings(:classification_has),
        :has_notes          => parse_boolean(:has_notes),
        :notes_has          => parse_strings(:notes_has),
        :has_comments       => parse_boolean(:has_comments, :limit => true),
        :comments_has       => parse_strings(:comments_has),
        :has_default_desc   => parse_boolean(:has_description),
        :ok_for_export      => parse_boolean(:ok_for_export),
      }
    end

    def build_object
      name_str = parse_string(:name, :limit => 100)
      author   = parse_string(:author, :limit => 100)

      params = {
        :rank             => parse_enum(:rank, :limit => Name.all_ranks),
        :citation         => parse_string(:citation, :default => ''),
        :deprecated       => parse_boolean(:deprecated, :default => false),
        :correct_spelling => parse_object(:correct_spelling, :limit => Name, :default => nil),
        :classification   => parse_string(:classification, :default => ''),
        :notes            => parse_string(:notes, :default => ''),
      }
      done_parsing_parameters!

      raise MissingParameter.new(:name_str) if name_str.blank?
      raise MissingParameter.new(:rank) if rank.blank?

      # Make sure name doesn't already exist.
      match = nil
      if author.blank?
        match = Name.find_by_text_name(name_str)
        name_str2 = name_str
      else
        match = Name.find_by_text_name_and_author(name_str, author)
        name_str2 = "#{name_str} #{author}"
      end
      raise NameAlreadyExists.new(name_str, match) if match

      # Make sure the name parses.
      names = Name.find_or_create_name_and_parents(name_str2)
      name  = names.last
      raise NameDoesntParse.new(name_str2) if name.nil?

      # Fill in information.
      name.attributes = params
      name.change_text_name(name_str, author, name.rank)
      name.change_deprecated(true) if name.deprecated

      # Save it and any implictly-created parents (e.g. genus when creating
      # species for unrecognized genus).
      for name in names
        if name and name.new_record?
          name.save
        end
      end
      return name
    end

    def update_params
      {
        :rank           => parse_enum(:set_rank, :limit => Name.all_ranks),
        :citation       => parse_string(:set_citation),
        :classification => parse_string(:set_classification),
        :notes          => parse_string(:set_notes),
      }
    end

    def must_have_edit_permission!(obj)
    end

    def delete
      raise NoMethodForAction(:delete, action)
    end
  end
end
