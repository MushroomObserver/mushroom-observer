# frozen_string_literal: true

require("test_helper")

class Inat
  class SequenceFieldDetectorTest < UnitTestCase
    def test_sequence_field_detects_dna_datatype
      field = { datatype: "dna", name: "ITS", value: "ACGTACGTACGT" }

      assert(SequenceFieldDetector.sequence_field?(field))
    end

    def test_sequence_field_detects_dna_in_name_with_valid_bases
      field = {
        datatype: "text",
        name: "DNA Sequence",
        value: "ACGTACGTACGT"
      }

      assert(SequenceFieldDetector.sequence_field?(field))
    end

    def test_sequence_field_rejects_short_sequences
      # Less than 10 base pairs should not match
      field = {
        datatype: "text",
        name: "DNA Sequence",
        value: "ACGT"
      }

      assert_not(SequenceFieldDetector.sequence_field?(field))
    end

    def test_sequence_field_rejects_non_dna_fields
      field = { datatype: "text", name: "Notes", value: "Some text" }

      assert_not(SequenceFieldDetector.sequence_field?(field))
    end

    def test_sequence_field_rejects_invalid_nucleotides
      field = {
        datatype: "text",
        name: "DNA Sequence",
        value: "XYZXYZXYZXYZ"
      }

      assert_not(SequenceFieldDetector.sequence_field?(field))
    end

    def test_extract_sequences_returns_empty_for_nil
      result = SequenceFieldDetector.extract_sequences(nil)

      assert_equal([], result)
    end

    def test_extract_sequences_returns_empty_for_empty_array
      result = SequenceFieldDetector.extract_sequences([])

      assert_equal([], result)
    end

    def test_extract_sequences_extracts_valid_sequences
      fields = [
        { datatype: "dna", name: "ITS", value: "ACGTACGTACGT" },
        { datatype: "text", name: "Notes", value: "Not a sequence" },
        { datatype: "dna", name: "LSU", value: "TGCATGCATGCA" }
      ]

      result = SequenceFieldDetector.extract_sequences(fields)

      assert_equal(2, result.count)
      assert_equal("ITS", result[0][:locus])
      assert_equal("ACGTACGTACGT", result[0][:bases])
      assert_nil(result[0][:archive])
      assert_equal("", result[0][:accession])
      assert_equal("", result[0][:notes])
      assert_equal("LSU", result[1][:locus])
      assert_equal("TGCATGCATGCA", result[1][:bases])
    end

    def test_extract_sequences_skips_blank_values
      fields = [
        { datatype: "dna", name: "ITS", value: "ACGTACGTACGT" },
        { datatype: "dna", name: "LSU", value: "" },
        { datatype: "dna", name: "SSU", value: nil }
      ]

      result = SequenceFieldDetector.extract_sequences(fields)

      assert_equal(1, result.count)
      assert_equal("ITS", result[0][:locus])
    end

    def test_extract_sequences_with_dna_in_field_name
      fields = [
        {
          datatype: "text",
          name: "ITS DNA Barcode",
          value: "ACGTACGTACGTACGT"
        }
      ]

      result = SequenceFieldDetector.extract_sequences(fields)

      assert_equal(1, result.count)
      assert_equal("ITS DNA Barcode", result[0][:locus])
      assert_equal("ACGTACGTACGTACGT", result[0][:bases])
    end

    def test_extract_sequences_handles_mixed_fields
      fields = [
        { datatype: "dna", name: "ITS", value: "ACGTACGTACGT" },
        { datatype: "text", name: "Collector", value: "John Doe" },
        { datatype: "text", name: "LSU DNA", value: "TGCATGCATGCA" },
        { datatype: "numeric", name: "pH", value: "7.5" }
      ]

      result = SequenceFieldDetector.extract_sequences(fields)

      assert_equal(2, result.count)
      assert_equal("ITS", result[0][:locus])
      assert_equal("LSU DNA", result[1][:locus])
    end
  end
end
