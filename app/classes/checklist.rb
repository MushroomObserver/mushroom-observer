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
    def initialize(project, location = nil,
                   include_sub_locations: false)
      @project = project
      @location = location
      base = project.visible_observations
      @observations =
        if location.present? && include_sub_locations
          sub_location_observations(base, location)
        elsif location.present?
          base.within_locations([location])
        else
          base
        end
    end

    def sub_location_observations(base, location)
      escaped = ActiveRecord::Base.sanitize_sql_like(
        location.name
      )
      tbl = Location.arel_table
      base.joins(:location).where(
        tbl[:name].matches("%, #{escaped}").
          or(tbl[:name].eq(location.name))
      )
    end

    delegate :target_name_ids, to: :@project

    # Number of target names attached to the project.
    def num_targets
      target_names.size
    end

    # Target names with at least one observation — direct or via a synonym
    # in this project's observations — counted by target name record.
    def num_targets_observed
      observed_target_name_ids.size
    end

    def num_targets_unobserved
      num_targets - num_targets_observed
    end

    # Taxa observed at rank <= Species (Form, Variety, Subspecies, Species).
    def species_level_observed_taxa
      taxa.select { |tuple| species_level_rank?(tuple[4]) }
    end

    # Taxa observed at rank > Species (Genus, infrageneric ranks, Group, ...).
    def higher_level_observed_taxa
      taxa.reject { |tuple| species_level_rank?(tuple[4]) }
    end

    # Distinct synonym groups among observed species-level taxa.
    # Names sharing a synonym_id collapse to one group; records with no
    # synonym_id are each their own group.
    def num_species_observed
      distinct_synonym_group_count(species_level_observed_taxa)
    end

    def num_higher_level_observed
      distinct_synonym_group_count(higher_level_observed_taxa)
    end

    # Target name tuples for which no synonym has an observation in the
    # project. Rendered in the "Unobserved targets" panel.
    def unobserved_target_taxa
      calc_checklist unless defined?(@unobserved_target_taxa)
      @unobserved_target_taxa
    end

    private

    def calc_checklist
      super
      merge_observed_targets_into_taxa
      compute_unobserved_target_taxa
    end

    def calc_counts
      super
      merge_target_names_into_counts
    end

    def target_names
      @target_names ||= @project.target_names.to_a
    end

    # Target name ids whose synonym group intersects with the project's
    # observed name ids. A name without a synonym_id forms a group of one.
    def observed_target_name_ids
      @observed_target_name_ids ||= compute_observed_target_name_ids
    end

    def compute_observed_target_name_ids
      return Set.new if target_names.empty?

      obs_name_ids = @observations.distinct.pluck(:name_id).to_set
      return Set.new if obs_name_ids.empty?

      syn_ids = target_names.filter_map(&:synonym_id).uniq
      siblings_by_syn = syn_ids.any? ? sibling_ids_by_synonym(syn_ids) : {}

      target_names.filter_map do |name|
        target_observed?(name, obs_name_ids, siblings_by_syn) ? name.id : nil
      end.to_set
    end

    def sibling_ids_by_synonym(syn_ids)
      Name.where(synonym_id: syn_ids).
        group_by(&:synonym_id).
        transform_values { |names| names.map(&:id) }
    end

    def target_observed?(name, obs_name_ids, siblings_by_syn)
      if name.synonym_id
        (siblings_by_syn[name.synonym_id] || []).
          any? { |id| obs_name_ids.include?(id) }
      else
        obs_name_ids.include?(name.id)
      end
    end

    # Add observed-via-synonym targets to @taxa so they appear in the
    # appropriate panel alongside query-observed names. Targets whose own
    # name_id is already in @taxa are left alone.
    def merge_observed_targets_into_taxa
      return if target_names.empty?

      @taxa = [] if @taxa.is_a?(Hash)
      taxa_ids = @taxa.to_set { |entry| entry[1] }
      observed = observed_target_name_ids
      target_names.each do |name|
        next if taxa_ids.include?(name.id)
        next unless observed.include?(name.id)

        @taxa << target_tuple(name)
      end
      @taxa.sort_by! { |entry| entry[0] }
    end

    def compute_unobserved_target_taxa
      observed = observed_target_name_ids
      @unobserved_target_taxa =
        target_names.
        reject { |name| observed.include?(name.id) }.
        sort_by(&:text_name).
        map { |name| target_tuple(name) }
    end

    def target_tuple(name)
      [name.text_name, name.id, name.deprecated, name.synonym_id, name.rank]
    end

    # Set 0 count for any target lacking a direct-name observation so the
    # link displays "(0)" next to the unobserved-target name.
    def merge_target_names_into_counts
      target_names.each do |name|
        @counts[name.text_name] ||= 0
      end
    end

    def species_level_rank?(rank)
      return false if rank.blank?

      Name.ranks[rank.to_s] <= Name.ranks[:Species]
    end

    def distinct_synonym_group_count(tuples)
      tuples.map { |tuple| tuple[3] || "id:#{tuple[1]}" }.uniq.size
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
        result[:deprecated], result[:synonym_id], result[:rank]]]
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
    Name.joins(:observations).merge(@observations).
      select(Name[:deprecated], Name[:text_name],
             Name[:id], Name[:rank], Name[:synonym_id]).
      distinct
  end
end
