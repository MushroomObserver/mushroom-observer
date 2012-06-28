# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class LocalizationFilesTest < UnitTestCase

  def assert_no_missing_translations(tags, type)
    clean_our_backtrace do
      missing = tags.uniq.reject(&:has_translation?)
      msg = "Missing #{type} translations:\n" + missing.map(&:inspect).sort.join("\n") + "\n"
      assert_block(msg) { missing.empty? }
    end
  end

################################################################################

  def test_localization_files_exist
    for lang in Language.all
      assert File.exists?(lang.localization_file)
    end
  end

  def test_syntax_of_official_export_file
    errors = []
    lang = Language.official
    Language.clear_verbose_messages
    lang.check_export_syntax
    errors += Language.verbose_messages
    assert_block("Bad syntax in language export files:\n" + errors.join("\n")) { errors.empty? }
  end

  # Make sure all "[:tag]" refs inside the translations exist.
  def test_embedded_refs
    errors = []
    for lang in Language.all
      data = File.open(lang.localization_file, 'r:utf-8') do |fh|
        YAML::load(fh)
      end
      tags = {}
      for tag in data.keys
        tags[tag.to_s.downcase] = true
      end
      for tag, str in data
        if str.is_a?(String)
          str.gsub(/[\[\=]:(\w+)/) do
            unless tags.has_key?($1.downcase)
              errors << "#{lang.locale} :#{tag} [:#{$1}]\n"
            end
          end
        end
      end
    end
    assert_true(errors.empty?, "Found #{errors.length} undefined tag " +
      "reference(s) in language files:\n" + errors.join(''))
  end

  def test_application_language_tags

    # First get list of tags defined in the main language file.
    lang = Language.official
    data = File.open(lang.export_file, 'r:utf-8') do |fh|
      YAML::load(fh)
    end
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

  def test_api_error_translations
    tags = []
    file = "#{RAILS_ROOT}/app/classes/api/errors.rb"
    File.open(file, 'r:utf-8') do |fh|
      fh.each_line do |line|
        if line.match(/^\s*class (\w+) < /) and
           not ['Error', 'ObjectError', 'BadParameterValue'].include?($1)
          tags << "api_#{$1.underscore.gsub('/','_')}".to_sym
        end
      end
    end
    file = "#{RAILS_ROOT}/app/classes/api/parsers.rb"
    File.open(file, 'r:utf-8') do |fh|
      fh.each_line do |line|
        if line.match(/BadParameterValue.new\([^()]*, :(\w+)\)/)
          tags << "api_bad_#{$1}_parameter_value".to_sym
        end
      end
    end
    assert_no_missing_translations(tags, 'API error')
  end

  def test_name_rank_translations
    tags = Name.all_ranks.map do |rank|
      [
        "rank_#{rank.to_s.downcase}".to_sym,
        "rank_plural_#{rank.to_s.downcase}".to_sym,
      ]
    end.flatten
    assert_no_missing_translations(tags, 'name rank')
  end

  def test_image_vote_translations
    tags = Image.all_votes.map do |val|
      [
        "image_vote_long_#{val}".to_sym,
        "image_vote_short_#{val}".to_sym,
        "image_vote_help_#{val}".to_sym,
      ]
    end.flatten
    assert_no_missing_translations(tags, 'image vote')
  end

  def test_review_status_translations
    tags = NameDescription.all_review_statuses.map do |status|
      "review_#{status}".to_sym
    end
    assert_no_missing_translations(tags, 'review status')
  end

  def test_naming_reason_translations
    tags = Naming::Reason.all_reasons.map do |reason|
      "naming_reason_label_#{reason}".to_sym
    end
    assert_no_missing_translations(tags, 'naming reason')
  end

  def test_description_source_translations
    tags = [:public, :foreign, :project, :source, :user].map do |source|
      [
        "description_full_title_#{source}".to_sym,
        "description_part_title_#{source}_with_text".to_sym,
      ]
    end.flatten
    assert_no_missing_translations(tags, 'description source title')
  end

  def test_site_data_translations
    tags = SiteData::ALL_FIELDS.map do |field|
      [
        "user_stats_#{field}".to_sym,
        "site_stats_#{field}".to_sym,
      ]
    end.flatten - [:user_stats_users] # not picking this up for some reason...
    assert_no_missing_translations(tags, 'site data field')
  end
end
