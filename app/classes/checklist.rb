# frozen_string_literal: true

#  = Checklist
#
#  This class calculates a checklist of species observed by users,
#  projects, etc.
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
  end

  # Build list of species observed by one User.
  class ForUser < Checklist
    def initialize(user)
      return (@user = user) if user.is_a?(User)

      raise("Expected User instance, got #{user.inspect}.")
    end

    def query
      super(
        subquery_scope: Observation.where(user_id: @user.id)
      )
    end
  end

  # Build list of species observed by one Project.
  class ForProject < Checklist
    def initialize(project)
      return (@project = project) if project.is_a?(Project)

      raise("Expected Project instance, got #{project.inspect}.")
    end

    def query
      super(
        subquery_scope: Observation.joins(:project_observations).
          where(ProjectObservation.arel_table[:project_id].eq(@project.id))
      )
    end
  end

  # Build list of species observed by one SpeciesList.
  class ForSpeciesList < Checklist
    def initialize(list)
      return (@list = list) if list.is_a?(SpeciesList)

      raise("Expected SpeciesList instance, got #{list.inspect}.")
    end

    def query
      super(
        subquery_scope: Observation.joins(:species_list_observations).
          where(SpeciesListObservation.arel_table[:species_list_id].
                eq(@list.id))
      )
    end
  end

  ##############################################################################

  def initialize
    @genera = @species = @taxa = nil
  end

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
    @taxa.values.sort
  end

  def self.all_site_taxa_by_user
    synonym_map = {}

    synonyms = Name.connection.select_rows(%(
    SELECT GROUP_CONCAT(n.id),
      MIN(CONCAT(n.deprecated, ',', n.text_name, ',', n.id, ',', n.rank))
    FROM names n
    GROUP BY IF(synonym_id, synonym_id, -id);
    ))

    synonyms.each do |row|
      ids, tuple = *row
      ids.split(",").each { |id| synonym_map[id.to_i] = tuple }
    end

    calculate_taxa_by_user(synonym_map)
  end

  def self.calculate_taxa_by_user(synonym_map)
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
    results = query_results_as_objects

    count_taxa_genera_and_species(results)
  end

  def query_results_as_objects
    query.map do |row|
      columns = row.cnc.split(",")
      { deprecated: columns[0].to_i,
        text_name: columns[1],
        id: columns[2].to_i,
        rank: columns[3].to_i }
    end
  end

  # These can't be hashes since they get sorted
  def count_taxa_genera_and_species(results)
    return if results.empty?

    @taxa = results.to_h do |result|
      [result[:text_name], [result[:text_name], result[:id]]]
    end

    # For Genus results, we're taking everything above Species up to Genus
    g_results = results.select do |result|
      [(Name.ranks[:Species] + 1)..Name.ranks[:Genus]].include?(result[:rank])
    end

    s_results = results.select do |result|
      result[:rank] <= Name.ranks[:Species]
    end

    # This could include groups etc, so we just want to store the genus names.
    # Doubles and parent/children will just overwrite each other, no IDs stored.
    @genera = g_results.to_h do |result|
      genus_name = result[:text_name].split(" ", 2)
      [genus_name, genus_name]
    end

    s_results.each do |result|
      g, s = result[:text_name].split(" ", 3)
      @genera[g] = g
      @species[[g, s]] = ["#{g} #{s}", result[:id]]
    end
  end

  # This `query` returns concatenated strings with info about the names we want.
  # The `minimum` here ensures one name per /group by synonym_id/.
  # The returned strings have to be unpacked (split on ",") to be used.
  #
  # (There's a way to have SQL return a JSON_OBJECT for the first name of each
  # sorted group via a window function, but it's much harder to write.)
  #
  # It should produce this SQL:
  # %(
  #   SELECT MIN(CONCAT(n.deprecated, ',', n.text_name, ',', n.id, ',', n.rank))
  #   FROM names n
  #   WHERE id IN (SELECT name_id FROM #{subquery})
  #   GROUP BY IF(synonym_id, synonym_id, -id);
  # )
  #
  # The subquery_scope that we select name_ids from can be anything:
  #
  # observations;
  # observations WHERE user_id = 252;
  # observations JOIN project_observations ON blah blah...
  # Oddly it doesn't make a difference whether the subquery is DISTINCT or
  # not. (because of the MIN)
  #
  def query(args = {})
    subquery_scope = args[:subquery_scope] || Observation

    Name.where(id: subquery_scope.select(:name_id)).
      select(
        (Name[:deprecated].cast('char') + "," + Name[:text_name] + "," +
         Name[:id].cast('char') + "," + Name[:rank].cast('char')).minimum.
         as("cnc")
      ).group("IF(synonym_id, synonym_id, -id)")
  end
end
