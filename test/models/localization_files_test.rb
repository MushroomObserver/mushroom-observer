require "test_helper"

class LocalizationFilesTest < UnitTestCase
  def assert_no_missing_translations(tags, type)
    missing = tags.uniq.reject(&:has_translation?)
    msg = "Missing #{type} translations:\n" +
          missing.map(&:inspect).sort.join("\n") + "\n"
    assert_empty missing, msg
  end

  ##############################################################################

  def test_localization_files_exist
    Language.all.each { |lang| assert File.exist?(lang.localization_file) }
  end

  def test_syntax_of_official_export_file
    errors = []
    lang = Language.official
    Language.clear_verbose_messages
    lang.check_export_syntax
    errors += Language.verbose_messages
    assert_empty errors, "Bad syntax in language export files:\n" +
                         errors.join("\n")
  end

  # Make sure all "[:tag]" refs inside the translations exist.
  def test_embedded_refs
    errors = []
    Language.all.each do |lang|
      data = File.open(lang.localization_file, "r:utf-8") do |fh|
        YAML.safe_load(fh)
      end
      tags = {}
      data.each_key { |tag| tags[tag.to_s.downcase] = true }
      data.each do |tag, str|
        next unless str.is_a?(String)
        str.gsub(/[\[\=]:(\w+)/) do
          unless tags.key?(Regexp.last_match(1).downcase)
            errors << "#{lang.locale} :#{tag} [:#{Regexp.last_match(1)}]\n"
          end
        end
      end
    end
    assert_true(errors.empty?, "Found #{errors.length} undefined tag " \
      "reference(s) in language files:\n" + errors.join(""))
  end

  def test_find_missing_tags_and_duplicate_method_defs
    tags = known_tags
    missing_tags = []
    duplicate_function_defs = []
    source_files("#{::Rails.root}/app", "#{::Rails.root}/test") do |file|
      missing_tags += missing_tags_in_file(file, tags)
      duplicate_function_defs += duplicate_function_defs_in_file(file)
    end
    assert_true(missing_tags.empty?,
                "Found #{missing_tags.length} undefined tag reference(s) " \
                "in source files:\n #{missing_tags.join("")}")
    assert_true(duplicate_function_defs.empty?,
                "Found #{duplicate_function_defs.length} duplicate method " \
                "definition(s) in source files:\n" +
                duplicate_function_defs.join(""))
  end

  def i18n_keys
    # Going through the backdoor to call a private method.  Yuck!
    TranslationString.translations(:en).keys
  end

  # Get Hash of tags we have translations for already.
  def known_tags
    (i18n_keys +
     # these are tags only used in unit tests
     %i[one two _unit_test_a _unit_test_x _unit_test_y _unit_test_z]).
      each.with_object({}) { |tag, h| h[tag.to_s.downcase] = true }
  end

  # Array of error msgs for tags in +file+ that we don't have translations for.
  def missing_tags_in_file(file, tags)
    errors = []
    n = 0
    File.readlines(file).each do |line|
      n += 1
      line.sub!(/(^#| # ).*/, "")
      line.gsub(/:(\w+)\.(l|t|tl|tp|tpl| |#|$)(\W|$)/) do
        unless tags.key?(Regexp.last_match(1).downcase)
          errors << "#{file} line #{n} [:#{Regexp.last_match(1)}]\n"
        end
      end
    end
    errors
  end

  # Get Array of error messages for methods in +file+ that are defined more
  # than once.  (I find myself copying and pasting method definitions and
  # forgetting to change the method name frequently.  Ruby does not complain
  # about this, and just overwrites the old method.  This is particularly
  # insidious in the unit tests, because there's absolutely no way to know.)
  def duplicate_function_defs_in_file(file)
    errors = []
    defs = {}
    stack = []
    n = 0
    File.readlines(file).each do |line|
      n += 1
      if line =~ /^(\s*)(class|module)\s/
        space = Regexp.last_match(1)
        stack << [{}, space]
        defs = {}
      elsif line.match(/^(\s*)end(\W|$)/) && stack.any?
        space = Regexp.last_match(1)
        defs = stack.pop[0] if space == stack[-1][1]
      elsif line =~ /^\s*def ([^\s()#]+)/
        if defs[Regexp.last_match(1)]
          errors << "#{file} line #{n} #{Regexp.last_match(1).inspect}\n"
        else
          defs[Regexp.last_match(1)] = true
        end
      end
    end
    if stack.any?
      errors << "#{file} line #{n} [file didn't parse right, " \
                "might be due to tabs?]\n"
    end
    errors
  end

  # Traverse a directory structure looking for source files.
  def source_files(*paths, &block)
    paths.each do |path|
      Dir.glob("#{path}/*").each do |file|
        if file =~ /\.(rb|rhtml|rxml|erb)$/
          yield(file)
        elsif File.directory?(file) && file.match(%r{\/\w+$})
          source_files(file, &block)
        end
      end
    end
  end

  def test_api_error_translations
    tags = []
    file = "#{::Rails.root}/app/classes/api/errors.rb"
    File.open(file, "r:utf-8") do |fh|
      fh.each_line do |line|
        next unless line.match(/^\s*class (\w+) < /) &&
                    !%w[Error ObjectError BadParameterValue].
                    include?(Regexp.last_match(1))
        tags << "api_#{Regexp.last_match(1).underscore.tr("/", "_")}".to_sym
      end
    end
    Dir.glob("#{::Rails.root}/app/classes/api/parsers/*.rb").each do |file|
      File.open(file, "r:utf-8") do |fh|
        fh.each_line do |line|
          next unless line.match(/BadParameterValue.new\([^()]*, :(\w+)\)/)

          tags << "api_bad_#{Regexp.last_match(1)}_parameter_value".to_sym
        end
      end
    end
    assert_no_missing_translations(tags, "API error")
  end

  def test_name_rank_translations
    tags = Name.all_ranks.map do |rank|
      [
        "rank_#{rank.to_s.downcase}".to_sym,
        "rank_plural_#{rank.to_s.downcase}".to_sym
      ]
    end.flatten
    assert_no_missing_translations(tags, "name rank")
  end

  def test_image_vote_translations
    tags = Image.all_votes.map do |val|
      [
        "image_vote_long_#{val}".to_sym,
        "image_vote_short_#{val}".to_sym,
        "image_vote_help_#{val}".to_sym
      ]
    end.flatten
    assert_no_missing_translations(tags, "image vote")
  end

  def test_review_status_translations
    tags = NameDescription.all_review_statuses.map do |status|
      "review_#{status}".to_sym
    end
    assert_no_missing_translations(tags, "review status")
  end

  def test_naming_reason_translations
    tags = Naming::Reason.all_reasons.map do |reason|
      "naming_reason_label_#{reason}".to_sym
    end
    assert_no_missing_translations(tags, "naming reason")
  end

  def test_description_source_translations
    tags = %i[public foreign project source user].map do |source|
      [
        "description_full_title_#{source}".to_sym,
        "description_part_title_#{source}_with_text".to_sym
      ]
    end.flatten
    assert_no_missing_translations(tags, "description source title")
  end

  def test_site_data_translations
    tags = SiteData::ALL_FIELDS.map do |field|
      [
        "user_stats_#{field}".to_sym,
        "site_stats_#{field}".to_sym
      ]
    end.flatten - [:user_stats_users] # not picking this up for some reason...
    assert_no_missing_translations(tags, "site data field")
  end
end
