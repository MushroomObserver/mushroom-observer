# frozen_string_literal: true

class Inat
  # Detects and extracts DNA sequence data from iNat observation fields
  # Shared logic used by Inat::Obs and Inat::ObservationUpdater
  module SequenceFieldDetector
    # Determines if an iNat observation field contains DNA sequence data
    #
    # @param field [Hash] iNat observation field with keys
    #   :datatype, :name, :value
    # @return [Boolean] true if field contains sequence data
    def self.sequence_field?(field)
      field[:datatype] == "dna" ||
        field[:name] =~ /DNA/ && field[:value] =~ /^[ACTG]{10,}/
    end

    # Extract sequence data from iNat observation fields
    #
    # @param observation_fields [Array<Hash>] array of iNat
    #   observation fields
    # @return [Array<Hash>] array of sequence hashes with keys:
    #   :locus, :bases, :archive, :accession, :notes
    def self.extract_sequences(observation_fields)
      return [] if observation_fields.blank?

      observation_fields.select { |f| sequence_field?(f) }.
        each_with_object([]) do |field, ary|
          next if field[:value].blank?

          ary << {
            locus: field[:name],
            bases: field[:value],
            archive: nil,
            accession: "",
            notes: ""
          }
        end
    end
  end
end
