# encoding: utf-8

require "yaml"

class DatabaseTranslations < ActiveRecord::Migration[4.2]
  def self.up
    begin
      drop_table :languages
      drop_table :translation_strings
      drop_table :translation_strings_versions
    rescue
    end

    create_table :languages, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.string :locale, limit: 40
      t.string :name, limit: 100
      t.string :order, limit: 100
      t.boolean :official, null: false
      t.boolean :beta, null: false
    end

    create_table :translation_strings, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.integer :version
      t.integer :language_id, null: false
      t.string :tag, limit: 100
      t.text :text
      t.datetime :modified
      t.integer :user_id
    end

    create_table :translation_strings_versions, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.integer :version
      t.integer :translation_string_id
      t.text :text
      t.datetime :modified
      t.integer :user_id
    end

    populate_new_tables
  end

  def self.down
    drop_table :languages
    drop_table :translation_strings
    drop_table :translation_strings_versions
  end

  class << self
    def populate_new_tables
      @now = Time.now.strftime("%Y-%m-%d %H:%M:%S")

      @names = {
        "de-DE" => "Deutsch",
        "el-GR" => "Ελληνικά",
        "en-US" => "English",
        "es-ES" => "Español",
        "fr-FR" => "Français",
        "pl-PL" => "Polski",
        "pt-BR" => "Português",
        "ru-RU" => "Русский"
      }

      @orders = {
        "de-DE" => "Deutsch",
        "el-GR" => "Ellenika",
        "en-US" => "English",
        "es-ES" => "Espanol",
        "fr-FR" => "Francais",
        "pl-PL" => "Polski",
        "pt-BR" => "Português",
        "ru-RU" => "Russkii"
      }

      @users = {
        "de-DE" => User.find(748),
        "el-GR" => User.find(2762),
        "en-US" => User.find(0),
        "es-ES" => User.find(252),
        "fr-FR" => User.find(252),
        "pl-PL" => User.find(3798),
        "pt-BR" => User.find(255),
        "ru-RU" => User.find(2070)
      }

      @string_id = 0
      for file in translation_files
        process_translation_file(file)
      end
    end

    def translation_files
      Dir.glob("#{RAILS_ROOT}/lang/ui/*.txt")
    end

    def parse_locale_from_translation_file(file)
      return Regexp.last_match(1) if file.match(/(\w+-\w+)\.txt$/)
      fail "Bad regex!"
    end

    def process_translation_file(file)
      puts "Processing #{file}..."
      @locale = parse_locale_from_translation_file(file)
      @language = create_language
      @data = YAML.load_file(file)
      @tags = get_list_of_good_tags(file)
      create_translation_strings
    end

    def create_language
      Language.create(
        locale: @locale,
        name: @names[@locale],
        order: @orders[@locale],
        official: (@locale == "en-US"),
        beta: false
      )
    end

    def create_translation_strings
      n = 0
      strings = []
      versions = []
      user_id = @users[@locale].id.to_s
      for tag in @tags
        id = @string_id += 1
        text = clean_string(@data[tag.to_s])
        strings << ["1", @language.id.to_s, tag.to_s, text, @now, user_id]
        versions << ["1", id.to_s, text, @now, user_id]
        if strings.length >= 100
          $stdout.write("#{(100.0 * n / @tags.length).round}%\r")
          finish_records(strings, versions)
          strings = []
          versions = []
        end
        n += 1
      end
      finish_records(strings, versions) if strings.any?
    end

    def clean_string(val)
      val.gsub(/\\n/, "\n").
        gsub(/[ \t]+\n/, "\n").
        gsub(/\n[ \t]+/, "\n").
        sub(/\A\s+/, "").
        sub(/\s+\Z/, "")
    end

    def finish_records(strings, versions)
      insert_records("translation_strings", strings,
                     "version, language_id, tag, text, modified, user_id")
      insert_records("translation_strings_versions", versions,
                     "version, translation_string_id, text, modified, user_id")
    end

    def insert_records(table, values, fields)
      values = values.map do |row|
        "(" + row.map { |v| Language.connection.quote(v) }.join(",") + ")"
      end.join(",")
      Language.connection.insert %(
        INSERT INTO #{table} (#{fields}) VALUES #{values}
      )
    end

    def get_list_of_good_tags(file)
      tags = []
      File.open(file, "r") do |fh|
        in_meat = false
        fh.each_line do |line|
          in_meat = true if line.match(/COMMON WORDS AND PHRASES/)
          return tags    if line.match(/DISABLE SYNTAX CHECKER/)
          tags << Regexp.last_match(1) if in_meat && line.match(/^"?(\w+)"?: [^ ]/)
        end
      end
      tags
    end
  end
end
