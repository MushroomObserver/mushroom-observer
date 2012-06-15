# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class LocalizationFilesTest < UnitTestCase
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
end
