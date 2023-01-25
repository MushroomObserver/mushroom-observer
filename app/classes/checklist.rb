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
#  genera::          List of genera (text_name) seen.
#  species::         List of species (text_name) seen.
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
    @genera = @species = nil
  end

  def num_genera
    calc_checklist unless @genera
    @genera.length
  end

  def num_species
    calc_checklist unless @species
    @species.length
  end

  def genera
    calc_checklist unless @genera
    @genera.values.sort
  end

  def species
    calc_checklist unless @species
    @species.values.sort
  end

  private

  def calc_checklist
    @genera = {}
    @species = {}
    synonyms = count_nonsynonyms_and_gather_synonyms
    count_synonyms(synonyms)
  end

  def count_nonsynonyms_and_gather_synonyms
    synonyms = {}
    Name.connection.select_rows(query).each do |id, name, syn_id, deprecated|
      if syn_id && deprecated == 1
        # wait until we find an accepted synonym
        synonyms[syn_id] ||= nil
      elsif syn_id
        # use the first accepted synonym we encounter
        synonyms[syn_id] ||= [name, id]
      else
        # count non-synonyms immediately
        count_species([name, id])
      end
    end
    synonyms
  end

  def count_synonyms(synonyms)
    synonyms.each do |syn_id, text_info|
      text_info ||= Name.where(synonym_id: syn_id, rank: ranks_to_consider).
                    order(deprecated: :asc).pick(:text_name, :id)
      count_species(text_info)
    end
  end

  def count_species(text_info)
    return if text_info.blank?

    text_name, id = text_info
    g, s = text_name.split(" ", 3)
    @genera[g] = g
    @species[[g, s]] = ["#{g} #{s}", id] # Can't be hash since it gets sorted
  end

  def ranks_to_consider
    Name.ranks.values_at("Species", "Subspecies", "Variety", "Form").join(", ")
  end

  def query(args = {})
    tables = [
      "names n",
      "observations o"
    ]
    conditions = [
      "n.id = o.name_id",
      "n.`rank` IN (#{ranks_to_consider})"
    ]
    tables += args[:tables] || []
    conditions += args[:conditions] || []
    %(
      SELECT n.id, n.text_name, n.synonym_id, n.deprecated
      FROM #{tables.join(", ")}
      WHERE (#{conditions.join(") AND (")})
    )
  end
end
