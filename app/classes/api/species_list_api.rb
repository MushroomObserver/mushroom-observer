# encoding: utf-8

class API
  class SpeciesListAPI < ModelAPI
    self.model = SpeciesList

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :comments,
      :user,
    ]

    def query_params
      {
        :where          => sql_id_condition,
        :created_at     => parse_time_range(:created_at),
        :updated_at     => parse_time_range(:updated_at),
        :date           => parse_date(:date),
        :users          => parse_users(:user),
        :names          => parse_strings(:name),
        :synonym_names  => parse_strings(:synonyms_of),
        :children_names => parse_strings(:children_of),
        :locations      => parse_strings(:location),
        :projects       => parse_strings(:project),
        :has_notes      => parse_boolean(:has_notes),
        :has_comments   => parse_boolean(:has_comments, :limit => true),
        :title_has      => parse_string(:title_has),
        :notes_has      => parse_string(:notes_has),
        :comments_has   => parse_string(:comments_has),
      }
    end

    def create_params
      {
        :title      => parse_string(:title, :limit => 100),
        :when       => parse_date(:date, :default => Time.now),
        :place_name => parse_place_name(:location, :limit => 1024, :default => Location.unknown),
        :notes      => parse_string(:notes, :default => ''),
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:title) if params[:title].blank?
    end

    def update_params
      {
        :title      => parse_string(:set_title, :limit => 100),
        :when       => parse_date(:set_date),
        :place_name => parse_place_name(:set_location, :limit => 1024),
        :notes      => parse_string(:set_notes)
      }
    end
  end
end
