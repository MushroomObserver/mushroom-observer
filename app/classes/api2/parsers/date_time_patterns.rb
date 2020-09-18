# frozen_string_literal: true

class API2
  module Parsers
    # Patterns and helpers used by both date and time parser.
    module DateTimePatterns
      MM              = "(0?[1-9]|1[012])"
      MMDD1           = '(0[1-9]|1[012])(0[1-9]|[12]\d|3[01])'
      MMDD2           = '(0?[1-9]|1[012])-(0?[1-9]|[12]\d|3[01])'
      MMDD3           = '(0?[1-9]|1[012])/(0?[1-9]|[12]\d|3[01])'
      YYYY            = '\d\d\d\d'
      YYYYMM1         = '\d{6}'
      YYYYMM2         = '\d\d\d\d-\d\d?'
      YYYYMM3         = '\d\d\d\d/\d\d?'
      YYYYMMDD1       = '\d{8}'
      YYYYMMDD2       = '\d\d\d\d-\d\d?-\d\d?'
      YYYYMMDD3       = '\d\d\d\d/\d\d?/\d\d?'
      YYYYMMDDHH1     = '\d{10}'
      YYYYMMDDHH2     = '\d\d\d\d-\d\d?-\d\d? \d\d?'
      YYYYMMDDHH3     = '\d\d\d\d/\d\d?/\d\d? \d\d?'
      YYYYMMDDHHMM1   = '\d{12}'
      YYYYMMDDHHMM2   = '\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?'
      YYYYMMDDHHMM3   = '\d\d\d\d/\d\d?/\d\d? \d\d?:\d\d?'
      YYYYMMDDHHMMSS1 = '\d{14}'
      YYYYMMDDHHMMSS2 = '\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?:\d\d?'
      YYYYMMDDHHMMSS3 = '\d\d\d\d/\d\d?/\d\d? \d\d?:\d\d?:\d\d?'

      def strip_time(str)
        # Fill in leading zeros in YYYY/M/D and YYYY-M-D style dates.
        str.gsub(/\D(?=\d(\D|$))/, "0").
          gsub(/\D/, "")
      end
    end
  end
end
