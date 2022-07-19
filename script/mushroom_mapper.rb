#!/usr/bin/env ruby
# frozen_string_literal: true

#
#  USAGE::
#
#    script/mushroom_mapper.rb
#
#  DESCRIPTION::
#
#  Creates JSON data file for Fungal Diversity Survey's
#  Mushroom Mapper app.
#
#  It writes output to:
#
#    RAILS_ROOT/public/mushroom_mapper.json
#    RAILS_ROOT/public/taxonomy.csv
#
#  Structure format:
#
#    version      = data["version"]
#    family_data  = data["families"][n]
#    family_name  = family_data["name"]
#    family_id    = family_data["id"]
#    genus_data   = family_data["genera"][n]
#    genus_name   = genus_data["name"]
#    genus_id     = genus_data["id"]
#    species_data = genus_data["species"][n]
#    species_name = species_data["name"]
#    species_id   = species_data["id"]
#
#    # Name of kth species in jth genus in ith family:
#    name = data["families"][i]["genera"][j]["species"][k]["name"]
#
################################################################################

require(File.expand_path("../config/boot.rb", __dir__))
require(File.expand_path("../config/environment.rb", __dir__))

require("json")

JSON_FILE = "#{Rails.root}/public/mushroom_mapper.json".freeze
RAW_FILE  = "#{Rails.root}/public/taxonomy.csv".freeze

# synonyms:         map from synonym_id to at least one accepted name_id
# aliases:          map from name_id to accepted name_id
# names:            map name_id to [ text_name, rank, deprecated ]
# ids:              map from text_name to id of "best" matching name
# observations:     map from genus name to number of observations in that genus
# classifications:  map from genus name to one or more classification(s)
# genus_to_family:  map from genus name to one or more family name(s)
# family_to_genus:  map from family name to list of genera in that family
# genus_to_species: map from genus name to list of species in that genus

# Build tables of synonyms and name data.
synonyms = {}
aliases  = {}
names    = {}
ids      = {}
name_data = Name.pluck(:id, :text_name, :rank, :deprecated, :synonym_id,
                       :correct_spelling_id)

# > 5 parameters needed for 2nd name.data block, and it's efficient
# to use name_data for the 1st block to avoid hitting db twice
name_data.
  each do |id, _text_name, _rank, deprecated, synonym_id, _correct_spelling_id|
    synonyms[synonym_id] = id if synonym_id && !deprecated
  end
name_data.
  each do |id, text_name, rank, deprecated, synonym_id, correct_spelling_id|
    real_id = id
    real_id = correct_spelling_id if correct_spelling_id
    real_id = synonyms[synonym_id] if synonym_id
    aliases[id] = real_id if real_id
    names[id] = [text_name, rank, deprecated]
    if ids[text_name]
      id2 = ids[text_name]
      _text_name2, _rank2, deprecated2 = names[id2]
      if !deprecated && !deprecated2
        warn("Multiple accepted names match #{text_name}: #{id2}, #{id}")
      elsif !deprecated && deprecated2
        ids[text_name] = id
      end
    else
      ids[text_name] = id
    end
  end

# Build table of number of observations per genus.
observations = {}
Observation.pluck(:name_id).each do
  next unless (real_id = aliases[id])

  text_name, rank, deprecated = names[real_id]
  next if rank > Name.ranks[:Genus]

  genus = text_name.sub(/ .*/, "")
  next if text_name == genus && deprecated

  observations[genus] = observations[genus].to_i + 1
end

# Build mapping from genus to famil(ies).
genus_to_family = {}
classifications = {}
# The official fungal nomenclature databases include slime molds, which
# are actually in Amoebozoa or Protozoa
fungal_nomenclature_kingdoms = %w[Amoebozoa Fungi Protozoa]
Name.with_correct_spelling.not_deprecated.with_rank("Genus").
  pluck(:id, :text_name, :classification).each do |id, genus, classification|
    kingdom =
      classification.to_s =~ /Kingdom: _([^_]+)_/ ? Regexp.last_match(1) : nil
    klass   =
      classification.to_s =~ /Class: _([^_]+)_/ ? Regexp.last_match(1) : nil
    order   =
      classification.to_s =~ /Order: _([^_]+)_/ ? Regexp.last_match(1) : nil
    family  =
      classification.to_s =~ /Family: _([^_]+)_/ ? Regexp.last_match(1) : nil
    num_obs = observations[genus].to_i
    list = classifications[genus] ||= []
    list << [id, kingdom, klass, order, family, genus, num_obs]
    next unless fungal_nomenclature_kingdoms.include?(kingdom)

    family2 = family || "Unknown Family in #{order || klass || kingdom}"
    hash = genus_to_family[genus] ||= {}
    hash[family2] = hash[family2].to_i + num_obs
    observations[family2] = observations[family2].to_i + num_obs
  end

# Build mapping from family to genus, complaining about ambiguous genera.
family_to_genus = {}
genus_to_family.keys.sort.each do |genus|
  hash = genus_to_family[genus]
  if hash.keys.length > 1
    warn("Multiple families for #{genus}: #{hash.inspect}")
  end
  family = hash.keys.min_by { |k| -hash[k] }
  list_of_genera = family_to_genus[family] ||= []
  list_of_genera << genus
end

# Build table of species in each genus.
genus_to_species = {}
Name.with_correct_spelling.not_deprecated.
  with_rank("Species").order(sort_name: :asc).
  pluck(:text_name).each do |species|
  genus = species.sub(/ .*/, "")
  list_of_species = genus_to_species[genus] ||= []
  list_of_species << species
end

# Write official JSON file.
data = {}
data["version"] = 1
data["families"] = []
family_to_genus.keys.sort.each do |family|
  next unless observations[family]

  family2 = family.sub(/^Unknown Family in /, "")
  warn("Missing family: #{family2}.") unless ids[family2]
  family_data = {}
  family_data["name"] = family
  family_data["id"]   = ids[family2]
  family_data["genera"] = []
  family_to_genus[family].sort.each do |genus|
    next unless observations[genus]

    warn("Missing genus: #{genus}.") unless ids[genus]
    genus_data = {}
    genus_data["name"] = genus
    genus_data["id"]   = ids[genus]
    genus_data["species"] = []
    next unless genus_to_species[genus]

    genus_to_species[genus].sort.each do |species|
      next unless observations[species]

      warn("Missing species: #{species}.") unless ids[species]
      genus_data["species"] << {
        "name" => species,
        "id" => ids[species]
      }
    end
    family_data["genera"] << genus_data
  end
  data["families"] << family_data
end
File.write(JSON_FILE, JSON.generate(data))

# Write raw data file.
File.open(RAW_FILE, "w") do |fh|
  fh.puts(%w[id kingdom class order family genus num_obs].join("\t"))
  classifications.keys.sort.each do |genus|
    fh.puts(classifications[genus].join("\t"))
  end
end

exit(0)
