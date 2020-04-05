class Mysql56 < ActiveRecord::Migration[4.2]
  def self.change_column(table, column, type, options = {})
    tmp_column = "#{column}_tmp"
    add_column(table, tmp_column, type, options)
    Name.connection.update("update #{table} set #{tmp_column}=#{column}")
    remove_column(table, column)
    rename_column(table, tmp_column, column)
  end

  def self.change_indexed_column(table, column, type, options = {})
    change_column(table, column, type, options)
    add_index(table, column)
  end

  def self.up
    change_column(:users, :notes, :text) # Not reversible in MySQL 5.6
    change_column(:users, :mailing_address, :text) # Not reversible in MySQL 5.6
    change_column(:queries, :flavor, :enum, limit: [:advanced_search, :all, :at_location, :at_where, :by_author, :by_editor, :by_rss_log, :by_user, :for_project, :for_target, :for_user, :in_set, :in_species_list, :inside_observation, :of_children, :of_name, :of_parents, :pattern_search, :regexp_search, :with_descriptions, :with_descriptions_by_author, :with_descriptions_by_editor, :with_descriptions_by_user, :with_descriptions_in_set, :with_observations, :with_observations_at_location, :with_observations_at_where, :with_observations_by_user, :with_observations_for_project, :with_observations_in_set, :with_observations_in_species_list, :with_observations_of_children, :with_observations_of_name])
    change_column(:queries, :model, :enum, limit: [:Comment, :Herbarium, :Image, :Location, :LocationDescription, :Name, :NameDescription, :Observation, :Project, :RssLog, :SpeciesList, :Specimen, :User])
    change_column(:names_versions, :rank, :enum, limit: [:Form, :Variety, :Subspecies, :Species, :Stirps, :Subsection, :Section, :Subgenus, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom, :Domain, :Group])
    change_column(:names, :author, :string, limit: 100)
    change_indexed_column(:image_votes, :user_id, :integer)
    change_indexed_column(:image_votes, :image_id, :integer)
  end

  def self.down
    change_indexed_column(:image_votes, :image_id, :integer, null: false)
    change_indexed_column(:image_votes, :user_id, :integer, null: false)
    change_column(:names, :author, :string, limit: 100, null: false)
    change_column(:names_versions, :rank, :enum, limit: [:Form, :Variety, :Subspecies, :Species, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom, :Domain, :Group])
    change_column(:queries, :model, :enum, limit: [:Comment, :Image, :Location, :LocationDescription, :Name, :NameDescription, :Observation, :Project, :RssLog, :SpeciesList, :User])
    change_column(:queries, :flavor, :enum, limit: [:advanced_search, :all, :at_location, :at_where, :by_author, :by_editor, :by_rss_log, :by_user, :for_project, :for_target, :for_user, :in_set, :in_species_list, :inside_observation, :of_children, :of_name, :of_parents, :pattern_search, :with_descriptions, :with_descriptions_by_author, :with_descriptions_by_editor, :with_descriptions_by_user, :with_descriptions_in_set, :with_observations, :with_observations_at_location, :with_observations_at_where, :with_observations_by_user, :with_observations_for_project, :with_observations_in_set, :with_observations_in_species_list, :with_observations_of_children, :with_observations_of_name])
  end
end
