# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

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
      elsif value.sub!(/^\[\[/, '')
      elsif value.sub!(/^\]\]/, '')
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

  # ---------------------------------------
  #  Make sure language tags files exist.
  # ---------------------------------------
  def test_language_files
    assert File.directory?(LANGUAGE_PATH)
    assert(Dir.glob(LANGUAGE_FILES).any?)
  end

  # ------------------------------------------
  #  Make sure languages all have same tags.
  # ------------------------------------------
  def test_language_tags
    files = Dir.glob(LANGUAGE_FILES)

    all_tags = {}
    tags_by_file = {}

    errors = []
    for file in files
      file2 = file.sub(/.*\//, '')
      data = YAML::load_file(file)
      this_tags = tags_by_file[file] = {}
      for tag in data.keys
        if this_tags[tag]
          errors << "#{file2} [:#{tag}]\n"
        end
        all_tags[tag] ||= {}
        this_tags[tag] ||= {}
      end
      assert(this_tags["app_banner"])
    end
    assert_block("Found #{errors.length} duplicate(s) in " +
      "language files:\n" + errors.join('')) { errors.empty? }

    errors = []
    for file in files
      file2 = file.sub(/.*\//, '')
      this_tags = tags_by_file[file]
      missing = all_tags.keys - this_tags.keys
      if missing.any?
        errors += missing.map {|x| "#{file2} [:#{x}]\n"}
      end
    end
    assert_block("Found #{errors.length} missing tag(s) in " +
      "language files:\n" + errors.join('')) { errors.empty? }
  end

  # ----------------------------------
  #  Check syntax of language files.
  # ----------------------------------
  def test_language_syntax
    for file in Dir.glob(LANGUAGE_FILES)
      YAML::load_file(file)
    end
  end

  # -------------------------------------------------------
  #  Look through application for obvious tag references.
  # -------------------------------------------------------
  def test_application_language_tags

    # First get list of tags defined in the main language file.
    data = YAML::load_file(LANGUAGE_MAIN_FILE)
    tags = {}
    for tag in data.keys
      tags[tag.to_s.downcase] = true
    end

    # Really, we should include the Globalite translations, too, but for now
    # let's just add the only two we actually use.
    tags['date_helper_abbr_month_names'] = true
    tags['date_helper_month_names']      = true

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

    # Now go through all source files looking for tag refs.
    errors = []
    source_files("#{RAILS_ROOT}/app") do |file|
      n = 0
      for line in File.readlines(file)
        n += 1
        line.sub!(/(^#| # ).*/, '')
        line.gsub(/:(\w+)\.(l|t|tl|tp|tpl| |#|$)(\W|$)/) do
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
      data = YAML::load_file(file)
      tags = {}
      for tag in data.keys
        tags[tag.to_s.downcase] = true
      end
      for tag, str in data
        if str.is_a?(String)
          str.gsub(/[\[=]:(\w+)/) do
            unless tags.has_key?($1.downcase)
              errors << "#{file} :#{tag} [:#{$1}]\n"
            end
          end
        end
      end
    end
    assert_true(errors.empty?, "Found #{errors.length} undefined tag " +
      "reference(s) in language files:\n" + errors.join(''))
  end
end
