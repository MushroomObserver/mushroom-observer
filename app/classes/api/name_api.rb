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
        :created_at         => parse_time_range(:created_at),
        :updated_at         => parse_time_range(:updated_at),
        :users              => parse_users(:user),
        :names              => parse_strings(:name),
        :synonym_names      => parse_strings(:synonyms_of),
        :children_names     => parse_strings(:children_of),
        :is_deprecated      => parse_boolean(:is_deprecated),
        :misspellings       => parse_enum(:misspellings, :limit => [:no, :either, :only], :default => :no),
        :has_synonyms       => parse_boolean(:has_synonyms),
        :locations          => parse_strings(:location),
        :species_lists      => parse_strings(:species_lists),
        :rank               => parse_enum(:rank, :limit => Name.all_ranks),
        :has_author         => parse_boolean(:has_author),
        :has_citation       => parse_boolean(:has_citation),
        :has_classification => parse_boolean(:has_classification),
        :has_notes          => parse_boolean(:has_notes),
        :has_comments       => parse_boolean(:has_comments, :limit => true),
        :has_default_desc   => parse_boolean(:has_description),
        :text_name_has      => parse_string(:text_name_has),
        :author_has         => parse_string(:author_has),
        :citation_has       => parse_string(:citation_has),
        :classification_has => parse_string(:classification_has),
        :notes_has          => parse_string(:notes_has),
        :comments_has       => parse_string(:comments_has),
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
