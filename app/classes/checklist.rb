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
#  num_names::       Number of distinct names.
#  genera::          List of genera (text_name) seen.
#  species::         List of species (text_name) seen.
#  names::           List of names seen.
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
        conditions: ["o.user_id = #{@user.id}"]
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
        tables: ["project_observations op"],
        conditions: ["op.observation_id = o.id",
                     "op.project_id = #{@project.id}"]
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
        tables: ["species_list_observations os"],
        conditions: ["os.observation_id = o.id",
                     "os.species_list_id = #{@list.id}"]
      )
    end
  end

  ##############################################################################

  def initialize
    @genera = @species = @names = nil
  end

  def num_genera
    calc_checklist unless @genera
    @genera.length
  end

  def num_species
    calc_checklist unless @species
    @species.length
  end

  def num_names
    calc_checklist unless @names
    @names.length
  end

  def genera
    calc_checklist unless @genera
    @genera.values.sort
  end

  def species
    calc_checklist unless @species
    @species.values.sort
  end

  def names
    calc_checklist unless @names
    @names.values.sort
  end

  private

  def calc_checklist
    @names = {}
    @genera = {}
    @species = {}
    synonyms = count_nonsynonyms_and_gather_synonyms
    count_synonyms(synonyms)
  end

  def count_nonsynonyms_and_gather_synonyms
    synonyms = {}
    Name.connection.select_rows(query).each do
      |id, name, syn_id, deprecated, rank|
      if syn_id && deprecated == 1
        # wait until we find an accepted synonym
        synonyms[syn_id] ||= nil
      elsif syn_id
        # use the first accepted synonym we encounter
        synonyms[syn_id] ||= [name, id, rank]
      else
        # count non-synonyms immediately
        count_species([name, id, rank])
      end
    end
    synonyms
  end

  def count_synonyms(synonyms)
    synonyms.each do |syn_id, text_info|
      unless text_info
        text_info = Name.where(synonym_id: syn_id).
                    order(deprecated: :asc).pick(:text_name, :id, :rank)
        text_info[2] = Name.ranks[text_info[2]]
      end
      count_species(text_info)
    end
  end

  def count_species(text_info)
    return if text_info.blank?

    text_name, id, rank = text_info
    @names[text_name] = [text_name, id]
    return unless rank < Name.ranks[:Genus]

    g, s = text_name.split(" ", 3)
    @genera[g] = g
    @species[[g, s]] = ["#{g} #{s}", id] # Can't be hash since it gets sorted
  end

  def query(args = {})
    tables = [
      "names n",
      "observations o"
    ]
    conditions = [
      "n.id = o.name_id"
    ]
    tables += args[:tables] || []
    conditions += args[:conditions] || []
    %(
      SELECT n.id, n.text_name, n.synonym_id, n.deprecated, n.rank
      FROM #{tables.join(", ")}
      WHERE (#{conditions.join(") AND (")})
    )
  end

  # <<-SQL.squish
  # SELECT DISTINCT
  #   COALESCE(
  #     name_plus, CONCAT(deprecated, ',', text_name, ',', id, ',', `rank`)
  #   ) AS data
  # FROM names
  # LEFT JOIN (
  #   SELECT synonym_id,
  #     MIN(
  #       CONCAT(deprecated, ',', text_name, ',', id, ',', `rank`)
  #     ) AS name_plus
  #   FROM names
  #   WHERE synonym_id IS NOT NULL
  #   GROUP BY synonym_id
  # ) AS temp ON names.synonym_id = temp.synonym_id
  # WHERE id IN (SELECT name_id FROM observations);
  # SQL

end
