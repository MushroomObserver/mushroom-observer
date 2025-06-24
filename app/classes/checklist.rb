# frozen_string_literal: true

#  = Checklist
#
#  This class calculates a checklist of species observed by users,
#  projects, etc.
#
#  == Class Methods
#
#  all_site_taxa_by_user::  Calculate checklist taxon stats for all users
#                           (only the stats, not the names)
#
#  == Methods
#
#  num_genera::      Number of genera seen.
#  num_species::     Number of species seen.
#  num_taxa::        Number of distinct taxa.
#  genera::          List of genera (text_name) seen.
#  species::         List of species (text_name) seen.
#  taxa::            List of taxa seen.
#
#  == Usage
#
#    data = Checklist::ForUser.new(user)
#    puts "Life List: #{data.num_species} species in #{data.num_genera} genera."
#
################################################################################

class Checklist
  # Build list of species observed by entire site.
  class ForSite < Checklist
    def initialize
      @observations = Observation.all
    end
  end

  # Build list of species observed by one User.
  class ForUser < Checklist
    def initialize(user)
      @user = user
      @observations = user.observations
    end
  end

  # Build list of species observed by one Project.
  class ForProject < Checklist
    def initialize(project, location = nil)
      @project = project
      @location = location
      @observations = if location.present?
                        project.observations.where(location: location)
                      else
                        project.observations
                      end
    end
  end

  # Build list of species observed by one SpeciesList.
  class ForSpeciesList < Checklist
    def initialize(list)
      @list = list
      @observations = list.observations
    end
  end

  ##############################################################################

  def num_genera
    calc_checklist unless @genera
    @genera.length
  end

  def num_species
    calc_checklist unless @species
    @species.length
  end

  def num_taxa
    calc_checklist unless @taxa
    @taxa.length
  end

  def genera
    calc_checklist unless @genera
    @genera.values.sort
  end

  def species
    calc_checklist unless @species
    @species.values.sort
  end

  def taxa
    calc_checklist unless @taxa
    @taxa
  end

  def duplicate_synonyms
    calc_checklist unless @duplicate_synonyms
    @duplicate_synonyms
  end

  def any_deprecated?
    calc_checklist unless @any_deprecated
    @any_deprecated
  end

  def counts
    calc_counts unless @counts
    @counts
  end

  # `+` here is Arel extensions shorthand for `CONCAT`
  # The group statement is to be sure names without synonyms are sorted
  # separately in the array by giving all of them negative values in the group.
  # The idea is that we don't want those with synonyms and those without
  # to overlap; putting them last is arbitrary.
  # rubocop:disable Style/StringConcatenation
  def self.all_site_taxa_by_user
    synonym_map = {}

    synonyms = Name.connection.select_rows(
      Name.select(
        Arel.sql("GROUP_CONCAT(names.id)"),
        (Name[:deprecated].cast("char") + "," +
         Name[:text_name].cast("char") + "," +
         Name[:id].cast("char") + "," +
         Name[:rank].cast("char")).minimum
      ).group(
        Name[:synonym_id].when(present?).then(Name[:synonym_id]).
        else(Name[:id] * -1)
      )
    )
    synonyms.each do |row|
      ids, tuple = *row
      ids.split(",").each { |id| synonym_map[id.to_i] = tuple }
    end

    calculate_taxa_by_user(synonym_map)
  end
  # rubocop:enable Style/StringConcatenation

  private_class_method def self.calculate_taxa_by_user(synonym_map)
    taxa = {}
    genera = {}
    species = {}
    Observation.select(:user_id, :name_id).each do |row|
      user_id = row[:user_id]
      name_id = row[:name_id]
      _dep, text_name, _id, rank = *synonym_map[name_id].split(",")
      g, s = *text_name.split
      taxa[user_id] ||= {}
      genera[user_id] ||= {}
      species[user_id] ||= {}
      taxa[user_id][text_name] = true
      genera[user_id][g] = true if rank.to_i <= Name.ranks[:Genus]
      if rank.to_i <= Name.ranks[:Species]
        species[user_id][[g, s].join(" ")] = true
      end
    end

    { users: taxa.keys,
      taxa: taxa.transform_values(&:size),
      genera: genera.transform_values(&:size),
      species: species.transform_values(&:size) }
  end

  private

  def calc_checklist
    @taxa = {}
    @genera = {}
    @species = {}
    @annotations = {}
    count_taxa_genera_and_species(query)
  end

  # These can't be hashes since they get sorted
  def count_taxa_genera_and_species(results)
    return if results.empty?

    @taxa = calc_taxa(results).sort
    @duplicate_synonyms = calc_duplicate_synonyms(results)
    @any_deprecated = results.any? { |result| result[:deprecated] }

    # For Genus results, we're taking everything above Species up to Genus
    relevant_ranks = ((Name.ranks[:Species] + 1)..Name.ranks[:Genus]).to_a
    g_results = results.select do |result|
      rank = Name.ranks[result[:rank]]
      relevant_ranks.include?(rank)
    end

    s_results = results.select do |result|
      Name.ranks[result[:rank]] <= Name.ranks[:Species]
    end

    # This could include groups etc, so we just want to store the genus names.
    # Doubles and parent/children will just overwrite each other, no IDs stored.
    @genera = g_results.to_h do |result|
      genus_name = result[:text_name].split(" ", 2)[0]
      [genus_name, genus_name]
    end

    s_results.each do |result|
      gn, sp, pr = result[:text_name].split(" ", 3)
      @genera[gn] = gn
      sp = "#{sp} #{pr}" if sp == "sp." && pr
      @species[[gn, sp]] = ["#{gn} #{sp}", result[:id]]
    end
  end

  def calc_taxa(results)
    results.to_h do |result|
      [result[:text_name],
       [result[:text_name], result[:id],
        result[:deprecated], result[:synonym_id]]]
    end.values
  end

  def calc_duplicate_synonyms(results)
    values = results.pluck(:synonym_id)
    values.tally.select { |value, count| value.present? && count > 1 }.keys
  end

  def calc_counts
    calc_checklist unless @taxa
    @counts = @observations.
              joins(:name).
              group("names.text_name").
              count
  end

  def query(_args = {})
    Name.where(id: @observations.select(:name_id)).
      select(Name[:deprecated], Name[:text_name],
             Name[:id], Name[:rank], Name[:synonym_id])
  end
end
