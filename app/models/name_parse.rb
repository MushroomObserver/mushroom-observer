#
#  = Name Parser
#
#  This class is used by NameSorter and a few controllers (e.g.
#  NameController, SpeciesListController) to help parse lists of names, such as
#  in bulk_name_edit, create/edit_species_list, and change_synonyms.  It splits
#  each line up into a name and an optional synonym:
#
#    Species name
#    Species name = Synonym name
#    Species name [comment] = Synonym name [comment]
#
#  The following is how I *think* it works based on a read-through.  I have
#  not actually tested the two examples given. -JPH
#
#  Usage:
#    File.new("species_list").each do |line|
#      np = NameParse.new(line)
#
#      np.line_str               # "Lichenomphalia umbellifera =
#                                   Omphalia ericetorum [Lichen Mushroom]"
#      np.name                   # "Lichenomphalia umbellifera"
#      np.search_name            # "Lichenomphalia umbellifera"
#      np.rank                   # :Species
#      np.comment                # nil
#      np.find_names             # (Array of Name instances matching
#                                   "L. umbellifera")
#      np.has_synonym            # true
#      np.synonym                # "Omphalia ericetorum"
#      np.synonym_search_name    # "Omphalia ericetorum"
#      np.synonym_rank           # :Species
#      np.synonym_comment        # "Lichen Mushroom"
#      np.find_synonym_names     # (Array of Name instances matching
#                                   "L. umbellifera")
#      np.line_str               # "Phyllum Myxomycota [Highly polyphyletic]"
#      np.name                   # "Phyllum Myxomycota"
#      np.search_name            # "Myxomycota"
#      np.rank                   # :Phyllum
#      np.comment                # "Highly polyphyletic"
#      np.find_names             # (Array of Name instances matching
#                                   "Myxomycota")
#      np.has_synonym            # false
#    end
#
#  The methods find_names and find_synonym_names both use
#  Name#find_names_filling_in_authors to look up matching Name's.
#
################################################################################

class NameParse
  attr_reader :line_str
  attr_reader :name
  attr_reader :rank
  attr_reader :search_name
  attr_reader :comment
  attr_reader :synonym
  attr_reader :synonym_rank
  attr_reader :synonym_search_name
  attr_reader :synonym_comment

  COMMENT_PAT = /^\s* ([^\[\]]*) \s+ \[(.*)\] \s*$/x

  # spl_line can be either:
  #   <name>
  #   <name> = <synonym>
  # with an optional [comment] at the end
  # and where <name> is one of
  #   <search_name>
  #   <rank> <search_name>
  # and <synonym> is either
  #   <synonym_search_name>
  #   <synonym_rank> <synonym_search_name>
  def initialize(spl_line)
    result = []
    name_str = ""
    @line_str = spl_line.strip_squeeze
    equal_pos = @line_str.index("=")
    if equal_pos
      @name = @line_str[0..equal_pos - 1].strip
      @synonym = @line_str[equal_pos + 1..-1].strip
      @synonym_comment = nil
      if match = COMMENT_PAT.match(@synonym)
        @synonym = match[1]
        @synonym_comment = match[2]
      end
      (@synonym_rank, @synonym_search_name) = parse_rank(@synonym)
    else
      @name = @line_str
      @comment = nil
      @synonym = nil
      @synonym_rank = nil
      @synonym_search_name = nil
      if match = COMMENT_PAT.match(@name)
        @name = match[1]
        @comment = match[2]
      end
    end
    (@rank, @search_name) = parse_rank(@name)
  end

  def has_synonym
    !@synonym.nil?
  end

  def find_names
    Name.find_names_filling_in_authors(@search_name, @rank)
  end

  def find_synonym_names
    result = []
    if @synonym
      result = Name.find_names_filling_in_authors(@synonym_search_name,
                                                  @synonym_rank)
    end
    result
  end

  def parse_rank(str)
    result = [nil, str]
    space_pos = str.index(" ")
    if space_pos
      rank = str[0..space_pos - 1].to_sym
      result = [rank, str[space_pos..-1].strip] if Name.all_ranks.member?(rank)
    end
    result
  end
end
