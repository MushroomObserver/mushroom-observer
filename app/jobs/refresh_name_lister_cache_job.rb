# frozen_string_literal: true

# Regenerates the name_lister data cache (MO.name_lister_cache_file).
# Building the genera/species list is expensive, so instead of doing it on
# every name_lister request, this writes it out as a standalone JS file
# that gets served directly, bypassing Rails.
class RefreshNameListerCacheJob < ApplicationJob
  queue_as :maintenance

  def perform
    genera = genus_list(genera_rows)
    species = species_rows
    occurs = tally_occurrences(species)
    valid = build_valid_synonyms(species, occurs)
    write_cache(genera, species_list(species, occurs, valid))
  end

  private

  def genera_rows
    Name.with_rank(:Genus).with_correct_spelling.
      order(:sort_name).
      pluck(:text_name, :deprecated)
  end

  # :Form..:Species is contiguous in the rank enum (Form/Variety/
  # Subspecies/Species, ranks 100-400) so this covers exactly the four
  # species-ish ranks the original query listed individually.
  def species_rows
    Name.rank(:Form, :Species).with_correct_spelling.
      order(:sort_name).
      pluck(:text_name, :author, :deprecated, :synonym_id)
  end

  # Place "*" after all accepted genera; drop the deprecated spelling of
  # any genus that also has an accepted ("*") form.
  def genus_list(rows)
    seen = {}
    list = rows.map do |name, deprecated|
      val = deprecated ? name : "#{name}*"
      seen[val] = true
      val
    end.uniq
    list.reject { |n| seen["#{n}*"] }
  end

  def tally_occurrences(species)
    species.each_with_object(Hash.new(0)) { |(name, *), occ| occ[name] += 1 }
  end

  # Map from synonym_id to the list of valid (non-deprecated) names sharing
  # that synonym group, so a deprecated species can list its valid synonyms.
  def build_valid_synonyms(species, occurs)
    species.each_with_object({}) do |(n, a, deprecated, s), valid|
      next unless s.to_i.positive? && !deprecated

      list = valid[s] ||= []
      name = disambiguated_name(n, a, occurs)
      list.push(name) unless list.include?(name)
    end
  end

  # Insert valid synonyms after each deprecated name; append "*" to all
  # accepted names; append "|author" when needed to disambiguate.
  def species_list(species, occurs, valid)
    species.map { |row| species_entry(row, occurs, valid) }.flatten
  end

  def species_entry(row, occurs, valid)
    n, a, deprecated, s = row
    name = disambiguated_name(n, a, occurs)
    name += "*" unless deprecated
    return name unless deprecated && valid[s]

    [name] + valid[s].map { |x| "= #{x}" }
  end

  def disambiguated_name(name, author, occurs)
    author.present? && occurs[name] > 1 ? "#{name}|#{author}" : name
  end

  def write_cache(genera, species)
    path = MO.name_lister_cache_file
    FileUtils.mkpath(File.dirname(path))
    File.write(path, cache_contents(genera, species))
  end

  def cache_contents(genera, species)
    <<~JS
      export let NL_GENERA = [#{genera.map { |n| "'#{escape(n)}'" }.join(", ")}];
      export let NL_SPECIES = [#{species.map { |n| "'#{escape(n)}'" }.join(", ")}];
      export let NL_NAMES = [];
    JS
  end

  # Tired of fighting with ActionView to get it to let me use the one in
  # helpers/javascript_helper.rb, so this is copied verbatim.
  def escape(str)
    str.to_s.gsub("\\", '\0\0').gsub("</", '<\/').gsub(/\r\n|\n|\r/, "\\n").
      gsub(/["']/) { |m| "\\#{m}" }
  end
end
