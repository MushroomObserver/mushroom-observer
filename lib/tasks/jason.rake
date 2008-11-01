namespace :jason do

  # ----------------------------
  #  Character encoding.
  # ----------------------------

  desc "Check for non-ISO-8859-1 characters in name authors."
  task(:check_for_special_characters => :environment) do
    print "Writing file \"y\"...\n"
    out = ""
    cd = Iconv.new('ISO-8859-1', 'UTF-8')
    for name in Name.find(:all)
      str = [
        name.id.to_s,
        name.text_name.to_s,
        name.author.to_s,
        name.citation.to_s,
        name.notes.to_s
      ].join("")
      out += str.gsub(/[ -~\t\r\n]/, '') + "\n"
    end
    out.gsub!(/\n+/, "\n")
    fh = File.open('y', 'w')
    fh.puts(out)
    fh.close
  end

################################################################################

  # ----------------------------
  #  Redcloth.
  # ----------------------------

  desc "Dump out all notes for obs, names, spls, comments to test RedCloth."
  task(:dump_notes => :environment) do
    notes = []
    print "Getting observation notes...\n"
    notes += Observation.connection.select_values  'SELECT DISTINCT notes         FROM observations   WHERE LENGTH(notes) > 0'
    print "Getting naming reasons...\n"
    notes += NamingReason.connection.select_values 'SELECT DISTINCT notes         FROM naming_reasons WHERE LENGTH(notes) > 0'
    print "Getting name notes...\n"
    notes += Name.connection.select_values         'SELECT DISTINCT notes         FROM names          WHERE LENGTH(notes) > 0'
    print "Getting image notes...\n"
    notes += Image.connection.select_values        'SELECT DISTINCT notes         FROM images         WHERE LENGTH(notes) > 0'
    print "Getting species list notes...\n"
    notes += SpeciesList.connection.select_values  'SELECT DISTINCT notes         FROM species_lists  WHERE LENGTH(notes) > 0'
    print "Getting location notes...\n"
    notes += Location.connection.select_values     'SELECT DISTINCT notes         FROM locations      WHERE LENGTH(notes) > 0'
    print "Getting notification templates...\n"
    notes += Notification.connection.select_values 'SELECT DISTINCT note_template FROM notifications  WHERE LENGTH(note_template) > 0'
    print "Getting comments...\n"
    notes += Comment.connection.select_values      'SELECT DISTINCT comment       FROM comments       WHERE LENGTH(comment) > 0'
    print "Writing notes.yml...\n"
    File.open('notes.yml', 'w') do |fh|
      fh.write notes.uniq.to_yaml
    end
    print "Done!\n"
  end

  desc "Convert all notes to HTML using textilize to test RedCloth."
  task(:test_redcloth => :environment) do
    include ActionView::Helpers::TextHelper # (for textilize)
    include ApplicationHelper
    notes = YAML::load(File.open('notes.yml'))
    print "Textilizing #{notes.length} strings...\n"
    notes.map! do |str|
      begin
        textilize(str).to_s
      rescue => e
        'Crashed: ' + e.to_s + "\n" + str
      end
    end
    print "Writing redcloth.yml...\n"
    File.open('redcloth.yml', 'w') do |fh|
      fh.write notes.map.to_yaml
    end
    print "Done!\n"
  end

################################################################################

  desc "Get list of browser ID strings from apache logs."
  task(:apache_browser_ids) do
    require 'vendor/plugins/browser_status/lib/browser_status'
    include BrowserStatus
    ids = {}
    totals = {}
    for file in Dir.glob('../../../logs/access_log-*').sort
      File.open(file) do |fh|
        fh.each_line do |line|
          if match = line.match(/(\S+) \S+ \S+ \[([^\]]*)\] "([^"]*)" (\d+) (\d+) "([^"]*)" "([^"]*)"/)
            ua = match[7]
	    type, ver = parse_user_agent(ua)
	    str = ver ? "#{type}_#{ver}" : type.to_s || 'none'
            ids[ua] ||= [str, 0]
	    ids[ua][1] += 1
	    totals[str] ||= 0
	    totals[str] += 1
	  end
        end
      end
    end
    print ids.keys.
      sort_by {|ua| ids[ua][0]}.
      map {|ua| "#{ids[ua].join(' ')} #{ua}\n"}.
      join(''), "\n"
    print totals.keys.sort.
      map {|str| "#{str} #{totals[str]}\n"}.
      join('')
  end

################################################################################

  # ----------------------------
  #  Translations.
  # ----------------------------

  task(:get_localization_strings_used) do
    strings = {}
    for file in (
      Dir.glob('app/views/*/*.r*').sort +
      Dir.glob('app/controllers/*.rb').sort +
      Dir.glob('app/helpers/*.rb').sort +
      Dir.glob('app/models/*.rb').sort
    ) do
      File.open(file) do |fh|
        fh.each_line do |line|
          line.gsub(/:(\w+)\.(l|t|t_nop)($|\W)/) do
            strings[$1] = true
          end
        end
      end
    end
    @need_strings = strings
  end

  task(:get_localization_strings_available) do
    strings = {}
    File.open("lang/ui/#{ENV['LOCALE']}.yml") do |fh|
      fh.each_line do |line|
        if line.match(/^(\w+):/)
          strings[$1] = true
        end
      end
    end
    @have_strings = strings
  end

  desc "Print full list of localization strings used in the code."
  task(:print_localization_strings_used =>
    :get_localization_strings_used) do
    print @need_strings.keys.sort.join("\n") + "\n"
  end

  desc "Print full list of localization strings in a given localization file (use LOCALE=en-US, for example)."
  task(:print_localization_strings_available =>
    :get_localization_strings_available) do
    print @have_strings.keys.sort.join("\n") + "\n"
  end

  desc "Check to make sure all localization strings that are used are available (select language using LOCALE=en-US, for example)."
  task(:check_localizations => [
    :get_localization_strings_used,
    :get_localization_strings_available
  ]) do
    print @need_strings.keys.select {|key|
      !@have_strings.has_key?(key)
    }.sort.join("\n") + "\n"
  end

################################################################################

  # ----------------------------
  #  Esslinger's checklist.
  # ----------------------------

  desc "Upload names from Esslinger's checklist."
  task(:upload_esslinger => :environment) do
    user = User.find(252) # jason

    # This is stolen from construct_approved_names in app_controller.
    File.open('names/names.txt') do |fh|
      fh.each_line do |name|
        name = name.strip!.squeeze(' ')
        if name.match(/^([A-Z])/)
          print $1

          name_parse = NameParse.new(name)
          results = Name.names_from_string(name_parse.search_name)
          if results.last.nil?
            print "\nError: #{name_parse.name}\n"
          else
            n = results.last
            n.rank  = name_parse.rank    if name_parse.rank
            n.notes = name_parse.comment if !n.id && name_parse.comment
            for n in results
              if n
                n.change_deprecated(false)
                n.save_if_changed(user, "Approved by jason, based on Esslinger's checklist.")
              end
            end
          end

          if name_parse.has_synonym
            results = Name.names_from_string(name_parse.synonym_search_name)
            if results.last.nil?
              print "\nError: = #{name_parse.synonym}\n"
            else
              n = results.last
              n.rank  = name_parse.synonym_rank    if name_parse.synonym_rank
              n.notes = name_parse.synonym_comment if !n.id && name_parse.synonym_comment
              n.change_deprecated(true)
              n.save_if_changed(user, "Deprecated by jason, based on Esslinger's checklist")
              for n in results[0..-2]
                n.save_if_changed(user, nil)
              end
            end
          end

        end
      end
    end
  end

################################################################################

  desc "Convert __Names__ in notes throughout to links."
  task(:rebuild_links => :environment) do
    include ApplicationHelper
    str = "This looks a lot like _Agaricus_, like _A. campestris_ or _X. elegans_.\n"
    print str
    print str = check_other_links(check_name_links(str))
    print textilize(str)
  end

################################################################################

  desc "test"
  task(:test => :environment) do
    include ApplicationHelper
    print "".blank? ? "yes\n" : "no\n"
    str = %(available "from Ret' __Amanita__ site:":http://pluto.njcc.com.)
    print str.tl, "\n"
  end
end
