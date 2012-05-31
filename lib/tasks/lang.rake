# encoding: utf-8

require 'yaml'
begin
  # This engine does a better job with Greek and Cyrillic characters.
  YAML::ENGINE.yamler = 'psych'
rescue
end

namespace :lang do
  desc 'Check syntax of official YAML file, integrate changes into database, refresh other YAML files.'
  task :update => [
    :check_official,
    :update_database,
    :update_files,
    'export:all'
  ]

  def export_file(lang)
    "#{RAILS_ROOT}/lang/ui/#{lang.locale}.txt"
  end

  def yaml_file(lang)
    "#{RAILS_ROOT}/lang/ui/#{lang.locale}.yml"
  end

  def official_yaml_file
    yaml_file(Language.official)
  end

  def load_file(file)
    YAML::load_file(file)
  end

  def write_file(file, data)
    File.open(file, 'w') do |fh|
      YAML::dump(data, fh)
    end
  end

  # This one has to be done without access to Language because it is used
  # to declare tasks before the MO environment has been loaded.
  def all_locales
    locales = []
    for file in Dir.glob("#{RAILS_ROOT}/lang/ui/*.yml")
      if file.match(/(\w+-\w+).yml$/)
        locales << $1
      end
    end
    return locales
  end

################################################################################

  desc 'Check syntax of official YAML file.'
  task(:check_official => :environment) do
    file = official_yaml_file
    puts "Checking #{file}"
    check_for_duplicates(file)
    load_file(file)
  end

  desc 'Check syntax of all YAML files.'
  task(:check_all => :environment) do
    for lang in Language.all
      file = yaml_file(lang)
      puts "Checking #{file}"
      check_for_duplicates(file)
      load_file(file)
    end
  end

  def check_for_duplicates(file)
    once = {}
    twice = {}
    File.open(file, 'r') do |fh|
      for line in fh.each_line
        if line.match(/^(\w+):/)
          twice[$1] = true if once[$1]
          once[$1] = true
        end
      end
    end
    if twice.any?
      puts "DUPLICATE TAGS IN: #{file}"
      for tag in twice.keys.sort
        puts tag
      end
      puts
    end
  end

################################################################################

  desc 'Update database with any changes in the official YAML file.'
  task(:update_database => :environment) do
    puts 'Updating database'
    @now = Time.now
    @admin = User.find(0)
    @lang = Language.official
    @tag_lookup = build_tag_lookup(@lang)
    @ignore = get_tags_to_ignore(yaml_file(@lang))
    @data = load_file(yaml_file(@lang))
    update_official_translation_strings
  end

  def build_tag_lookup(lang)
    tag_lookup = {}
    for str in lang.translation_strings
      tag_lookup[str.tag] = str
    end
    return tag_lookup
  end

  def get_tags_to_ignore(file)
    tags = {}
    File.open(file, 'r') do |fh|
      in_meat = false
      for line in fh.each_line
        in_meat = true  if line.match(/COMMON WORDS AND PHRASES/)
        in_meat = false if line.match(/DISABLE SYNTAX CHECKER/)
        tags[$1] = true if not in_meat and line.match(/^(\w+):/)
      end
    end
    return tags
  end

  def update_official_translation_strings
    for tag, new_val in @data
      if new_val.is_a?(String) and not @ignore[tag]
        new_val = clean_string(new_val)
        unless str = @tag_lookup[tag]
          puts "  adding :#{tag}"
          create_translation_string(tag, new_val)
        else
          old_val = clean_string(str.text)
          if new_val != old_val
            puts "  updating :#{tag}"
            puts "    was #{old_val.inspect}"
            puts "    was #{new_val.inspect}"
            update_translation_string(str, new_val)
          end
        end
      end
    end
  end

  def create_translation_string(tag, val)
    TranslationString.create(
      :language => @lang,
      :tag => tag,
      :text => val,
      :modified => @now,
      :user => @admin
    )
  end

  def update_translation_string(str, val)
    str.update_attributes(
      :text => val,
      :modified => @now
    )
  end

################################################################################

  desc 'Refresh unofficial YAML files from database.'
  task(:update_files => :environment) do
    for lang in Language.unofficial
      puts "Refreshing #{lang.locale}"
      refresh_file(lang)
    end
  end

  def refresh_file(lang)
    file = yaml_file(lang)
    data = load_file(file)
    merge_database_strings(data, Language.official)
    merge_database_strings(data, lang)
    # save_old_file(file)
    write_file(file, data)
  end

  def merge_database_strings(data, lang)
    for str in lang.translation_strings
      data[str.tag] = str.text
    end
  end

  def save_old_file(file)
    File.delete("#{file}.old") if File.exists?("#{file}.old")
    File.rename(file, "#{file}.old")
  end

################################################################################

  desc 'Strip unused tags in unofficial locales from database.'
  task(:strip => :environment) do
    okay_tags = build_tag_lookup(Language.official)
    for lang in Language.unofficial
      puts "Stripping #{lang.locale}"
      for str in lang.translation_strings
        if !okay_tags[str.tag]
          puts "  deleting :#{str.tag}"
          str.destroy
        end
      end
    end
  end

################################################################################

  namespace :import do
    desc 'Import all unofficial locales from text files (debug only, really).'
    task(:all => :environment) do
      for lang in Language.unofficial
        import_from_file(lang)
      end
    end

    for locale in all_locales
      desc('Import unofficial locale from hand-editable text file.')
      task(locale => :environment) do |task|
        lang = Language.find_by_locale(task.name.sub(/.*:/, ''))
        raise 'Can only import unofficial languages!' if !lang or lang.official
        import_from_file(lang)
      end
    end
  end

  def import_from_file(lang)
    file = export_file(lang)
    puts "Importing #{file}"
    @now = Time.now
    @admin = User.find(0)
    @lang = lang
    @tag_lookup = build_tag_lookup(lang)
    @ignore = get_tags_to_ignore(official_yaml_file)
    @new_data = load_file(file)
    @old_data = {}
    merge_database_strings(@old_data, Language.official)
    merge_database_strings(@old_data, lang)
    update_unofficial_translation_strings
  end

  def update_unofficial_translation_strings
    for tag, new_val in @new_data
      new_val = clean_string(new_val)
      old_val = clean_string(@old_data[tag])
      if not new_val.is_a?(String)
        puts "BAD_CLASS: #{tag} #{new_val.class.name}"
      elsif not old_val
        puts "UNEXPECTED: #{tag}"
      elsif @ignore[tag]
        puts "IGNORING: #{tag}"
      elsif old_val != new_val
        unless str = @tag_lookup[tag]
          puts "  adding :#{tag}"
          puts  "    was #{old_val.inspect}"
          puts  "    now #{new_val.inspect}"
          # create_translation_string(tag, new_val)
        else
          puts "  updating :#{tag}"
          puts  "    was #{old_val.inspect}"
          puts  "    now #{new_val.inspect}"
          # update_translation_string(str, new_val)
        end
      end
    end
  end

################################################################################

  namespace :export do
    desc 'Export all unofficial locales to text files in hand-editable form.'
    task(:all => :environment) do
      for lang in Language.unofficial
        export_to_file(lang)
      end
    end

    for locale in all_locales
      desc 'Export locale to text file in hand-editable form.'
      task(locale => :environment) do |task|
        lang = Language.find_by_locale(task.name.sub(/.*:/, ''))
        raise 'Can only export unofficial languages!' if !lang or lang.official
        export_to_file(lang)
      end
    end
  end

  def export_to_file(lang)
    file = export_file(lang)
    puts "Exporting #{file}"
    all_tags = {}
    merge_database_strings(all_tags, Language.official)
    merge_database_strings(all_tags, lang)
    translated_tags = {}
    merge_database_strings(translated_tags, lang)
    write_editable_file(file, all_tags, translated_tags)
  end

  def read_template
    File.open(official_yaml_file, 'r').readlines
  end

  def write_editable_file(file, all_tags, translated_tags)
    template = read_template
    File.open(file, 'w') do |fh|
      in_tag = false
      for line in template
        if line.match(/^(['"]?(\w+)['"]?:)/)
          out, tag = $1, $2
          out += translated_tags[tag] ? ' ' : '  '
          out += format_string(all_tags[tag])
          fh.puts(out)
          in_tag = true if line.match(/ >\s*$/)
        elsif in_tag
          in_tag = false unless line.match(/\S/)
        elsif line.match(/DISABLE SYNTAX CHECKER/)
          break
        else
          fh.write(line)
        end
      end
    end
  end

  def format_string(val)
    if val.match(/\\n|\n/)
      format_multiline_string(val)
    elsif val.match(/[:#\[\]]/) or
          val.match(/^(no|yes)$/i) or
          (val.match(/^\W/) and val.force_encoding('binary')[0].ord < 128)
      escape_string(val)
    elsif val == ''
      '""'
    else
      val
    end
  end

  def format_multiline_string(val)
    val = val.sub(/(\\n|\n)+\Z/, '')
    out = ">\n"
    for line in val.split(/\\n|\n/)
      out += '  ' + line + "\\n\n"
    end.join
    return out
  end

  def escape_string(val)
    '"' + val.gsub(/([\"\\])/, '\\\\\\1') + '"'
  end

  def clean_string(val)
    val.gsub(/\\n/, "\n").
        gsub(/[ \t]+\n/, "\n").
        gsub(/\n[ \t]+/, "\n").
        sub(/\A\s+/, '').
        sub(/\s+\Z/, '')
  end
end
