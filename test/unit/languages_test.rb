require File.dirname(__FILE__) + '/../boot'

class LanguagesTest < UnitTestCase

  LANGUAGE_PATH  = "#{RAILS_ROOT}/lang/ui"
  LANGUAGE_FILES = "#{LANGUAGE_PATH}/*.yml"
  LANGUAGE_MAIN_FILE = "#{LANGUAGE_PATH}/en-US.yml"

  def validate_multiliner(lines, &block)
    while true
      if lines.empty?
        block.call('[premature EOF]')
        break
      end
      line = lines.shift
      if line.match(/^ *$/)
        break
      elsif !line.match(/^ +/)
        block.call(line)
        break
      elsif !validate_square_brackets(line)
        block.call(line)
      end
    end
  end

  def validate_one_liner(value, &block)
    if value.match(/^[\[\]\-]/) or
       value.match(/^".*[^"]$/) or
       value.match(/^'.*[^']$/) or
       value.match(/^".*[^\\]".*"$/) or
       value.match(/^'.*[^\\]'.*'$/) or
       !validate_square_brackets(value)
      block.call
    end
  end

  def validate_square_brackets(value)
    value = value.dup
    pass = true
    while value.match(/\S/)
      if value.sub!(/^[^\[\]]+/, '')
      elsif value.sub!(/^\[\w+\]/, '')
      elsif value.sub!(/^\[:\w+(?:\(([^\[\]]+)\))?\]/, '')
        if $1 && !validate_square_brackets_args($1)
          pass = false
          break
        end
      else
        pass = false
        break
      end
    end
    return pass
  end

  def validate_square_brackets_args(args)
    pass = true
    for pair in args.split(',')
      if !pair.match(/^ :?\w+ = (
            '.*' | ".*" | -?\d+(\.\d+)? | :\w+ | [a-z][a-z_]*\d*
          )$/x)
        pass = false
        break
      end
    end
    return pass
  end

################################################################################

  # Make sure language tags files exist.
  def test_language_files
    assert File.directory?(LANGUAGE_PATH)
    assert(Dir.glob(LANGUAGE_FILES).any?)
  end

  # ------------------------------------------
  #  Make sure languages all have same tags.
  # ------------------------------------------
  def test_language_tags
    files = Dir.glob(LANGUAGE_FILES)

    tags = {}
    this_tags = {}

    errors = []
    for file in files
      h = this_tags[file] = {}
      x = {}
      y = {}
      for line in IO.readlines(file)
        file2 = file.sub(/.*\//, '')
        if line.match(/^(\w+):/)
          if h[$1]
            errors << "#{file2} [:#{$1}]\n"
          end
          x = tags[$1] ||= {}
          y = h[$1]    ||= {}
        end
        if !line.match(/^\s*#/)
          line.gsub(/\[(\w+)\]/) do
            x[$1] = y[$1] = nil
          end
        end
      end
      assert(h["app_banner"])
    end
    assert_true(errors.empty?, "Found #{errors.length} duplicate(s) in " +
      "language files:\n" + errors.join(''))

    errors = []
    mismatches = {}
    for file in files
      file2 = file.sub(/.*\//, '')
      h = this_tags[file]
      missing = tags.keys - h.keys
      if !missing.empty?
        errors += missing.map {|x| "#{file2} [:#{x}]\n"}
      else
        for key in h.keys
          missing = tags[key].keys - h[key].keys
          if !missing.empty?
            mismatches[key] = nil
          end
        end
      end
    end
    assert_true(errors.empty?, "Found #{errors.length} missing tag(s) in " +
      "language files:\n" + errors.join(''))

    # The translataions are too free-form now for this test to be meaningful.
    # # These are known to have argument mismatches.
    # mismatches.delete('query_title_all')
    # assert_equal([], mismatches.keys.sort, "Arguments don't agree for these keys in all the files.")
  end

  # ----------------------------------
  #  Check syntax of language files.
  # ----------------------------------
  def test_language_syntax
    errors = []
    for file in Dir.glob(LANGUAGE_FILES)
      lines = File.readlines(file)
      num = lines.length
      while !lines.empty?
        case line = lines.shift
        when /^#/, /^ *$/
        when /^\w+:  ?(?!>)(\S(.*\S)?)/
          validate_one_liner($1) do
            errors << "#{file} line #{num - lines.length}: #{line}"
          end
        when /^\w+:  ?> *$/
          validate_multiliner(lines) do |line|
            errors << "#{file} line #{num - lines.length}: #{line}"
          end
        else
          errors << "#{file} line #{num - lines.length}: #{line}"
        end
      end
    end
    assert_true(errors.empty?, "Found #{errors.length} error(s) in " +
      "language files:\n" + errors.join(''))
  end

  # -------------------------------------------------------
  #  Look through application for obvious tag references.
  # -------------------------------------------------------
  def test_application_language_tags

    # First get list of tags defined in the main language file.
    tags = {}
    for line in File.readlines(LANGUAGE_MAIN_FILE)
      if line.match(/^(\w+):/)
        tags[$1.downcase] = true
      end
    end

    # Traverse a directory structure looking for source files.
    def source_files(path, &block)
      for file in Dir.glob("#{path}/*")
        if file.match(/\.(rb|rhtml)$/)
          block.call(file)
        elsif File.directory?(file) and
          file.match(/\/\w+$/)
          source_files(file, &block)
        end
      end
    end

    # No go through all source files looking for tag refs.
    errors = []
    source_files("#{RAILS_ROOT}/app") do |file|
      n = 0
      for line in File.readlines(file)
        n += 1
        line.gsub(/:(\w+)\.(l|t|tl|tp|tpl)(\W|$)/) do
          if !tags.has_key?($1.downcase)
            errors << "#{file} line #{n} [:#{$1}]\n"
          end
        end
      end
    end

    assert_true(errors.empty?, "Found #{errors.length} undefined tag " +
      "reference(s) in source files:\n" + errors.join(''))
  end

  # -----------------------------------------
  #  Check embedded tags in language files.
  # -----------------------------------------
  def test_embedded_refs
    errors = []
    for file in Dir.glob(LANGUAGE_FILES)

      # Gather list of tags defined first.
      tags = {}
      for line in File.readlines(file)
        tags[$1.downcase] = true if line.match(/^(\w+):/)
      end

      # Now look for embedded refs.
      n = 0
      for line in File.readlines(file)
        n += 1
        line.gsub(/[\[=]:(\w+)/) do
          if !tags.has_key?($1.downcase)
            errors << "#{file} line #{n} [:#{$1}]\n"
          end
        end
      end
    end

    assert_true(errors.empty?, "Found #{errors.length} undefined tag " +
      "reference(s) in language files:\n" + errors.join(''))
  end
end
