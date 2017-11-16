class API
  module Parsers
    # Patterns and helpers used by both date and time parser.
    module DateTimePatterns
      MM              = "(0?[1-9]|1[012])".freeze
      MMDD1           = '(0[1-9]|1[012])(0[1-9]|[12]\d|3[01])'.freeze
      MMDD2           = '(0?[1-9]|1[012])-(0?[1-9]|[12]\d|3[01])'.freeze
      MMDD3           = '(0?[1-9]|1[012])/(0?[1-9]|[12]\d|3[01])'.freeze
      YYYY            = '\d\d\d\d'.freeze
      YYYYMM1         = '\d{6}'.freeze
      YYYYMM2         = '\d\d\d\d-\d\d?'.freeze
      YYYYMM3         = '\d\d\d\d/\d\d?'.freeze
      YYYYMMDD1       = '\d{8}'.freeze
      YYYYMMDD2       = '\d\d\d\d-\d\d?-\d\d?'.freeze
      YYYYMMDD3       = '\d\d\d\d/\d\d?/\d\d?'.freeze
      YYYYMMDDHH1     = '\d{10}'.freeze
      YYYYMMDDHH2     = '\d\d\d\d-\d\d?-\d\d? \d\d?'.freeze
      YYYYMMDDHH3     = '\d\d\d\d/\d\d?/\d\d? \d\d?'.freeze
      YYYYMMDDHHMM1   = '\d{12}'.freeze
      YYYYMMDDHHMM2   = '\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?'.freeze
      YYYYMMDDHHMM3   = '\d\d\d\d/\d\d?/\d\d? \d\d?:\d\d?'.freeze
      YYYYMMDDHHMMSS1 = '\d{14}'.freeze
      YYYYMMDDHHMMSS2 = '\d\d\d\d-\d\d?-\d\d? \d\d?:\d\d?:\d\d?'.freeze
      YYYYMMDDHHMMSS3 = '\d\d\d\d/\d\d?/\d\d? \d\d?:\d\d?:\d\d?'.freeze

      def strip_time(str)
        # Fill in leading zeros in YYYY/M/D and YYYY-M-D style dates.
        str.gsub(/\D(?=\d(\D|$))/, "0").
          gsub(/\D/, "")
      end
    end
  end
end
