namespace :jason do
  desc "Test rake environment."
  task(:test => :environment) do
    print "Success!\n"
  end

  desc "Test textile."
  task(:test_textile => :environment) do
    include ActionView::Helpers::TextHelper # (for textilize)
    include ApplicationHelper
    str = '<img href="http://blah.com/blah.jpg"> !http://blah.com/foo.jpg!'
    print textilize(str).to_s
  end

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

  desc "Get list of browser ID strings from apache logs."
  task(:apache_browser_ids) do
    require 'vendor/plugins/browser_status/lib/browser_status'
    include BrowserStatus
    ids = {}
    totals = {}
    for file in Dir.glob('../../../logs/access_log-2008-09-11-*').sort
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
end
