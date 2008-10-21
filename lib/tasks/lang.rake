namespace :lang do

  desc "Resort translations according to English one, filling in missing ones, and moving extras to the end."
  task(:clean) do

    # Use English translations as the template.  Will write the other languages
    # in the same order, with the same comments.
    english = 'lang/ui/en-US.yml'
    template = ''
    File.open(english) do |fh|
      template = fh.readlines
    end

    # Loop through other languages (skipping English of course).
    dups_in_english = {}
    for filename in Dir.glob('lang/ui/*.yml').sort
      if filename != english

        # Get a hash mapping keys to translations.
        strings = {}
        dups = {}
        File.open(filename) do |fh|
          key = nil
          fh.each_line do |line|
            if line.match(/^(\w+):/)
              key = $1
              # Keep list of keys that are used more than once.
              dups[key] = true if strings[key]
              strings[key] = line
            elsif line.match(/^#/)
              key = nil
            elsif key
              strings[key] += line
            end
          end
        end

        # Clean up translations: remove trailing whitespace.
        strings.keys.each do |key|
          lines = strings[key]
          lines.gsub!(/[^\S\n]+\n/, "\n")
          lines.sub!(/\s+\Z/, "\n")
          # (make sure there is one trailing blank line for multi-line values)
          lines += "\n" if lines.match(/\n./)
          strings[key] = lines
        end

        # Create new file by copying the English template and replacing all the
        # string values with their corresponding translations.
        blanks = 0
        result = ''
        missing = {}
        keys_in_english = {}
        for line in template
# print "> [#{line.sub(/\n\Z/,'')}]"
          # Comment: assume this ends previous value.
          if line.match(/^#/)
# print " -> comment\n"
# print "()\n" * blanks if blanks > 0
            result += "\n" * blanks if blanks > 0
# print "(#{line.sub(/\n\Z/,'')})\n"
            result += line
            blanks = 0
            doing_missing = false
          # Blank line: hold on to these until we know what to do with them.
          elsif !line.match(/\S/)
            blanks += 1
# print " -> blank(#{blanks})\n"
          # New key: if recognized insert translation, else copy English one.
          elsif line.match(/^(\w+):/)
            key = $1
# print " -> key(#{key})\n"
            # (check for duplicates in English translation, too)
            if keys_in_english[key]
              print "Duplicate key in English: #{key}\n" if !dups_in_english[key]
              dups_in_english[key] = true
            end
            keys_in_english[key] = true
# print "()\n" * blanks if blanks > 0
            result += "\n" * blanks if blanks > 0
            if strings[key]
              # (preserve number of spaces after colon for ones that exist)
# print "found: (#{strings[key].sub(/\n\Z/,'')})\n"
              result += strings[key]
              strings.delete(key)
              doing_missing = false
            else
              # (use two spaces after colon for missing translations)
# print "missing: (#{line.sub(/:\s*/, ':  ').sub(/\n\Z/,'')})\n"
              result += line.sub(/:\s*/, ':  ')
              missing[key] = true
              doing_missing = true
            end
            blanks = 0
          # All other lines must be "folded lines" from "key: >" constructs.
          elsif doing_missing
# print " -> missing\n"
# print "missing: ()\n" * blanks if blanks > 0
            result += "\n" * blanks if blanks > 0
# print "missing: (#{line.sub(/\n\Z/,'')})\n"
            result += line
            blanks = 0
          else
# print " -> ignore\n"
            # (this has the effect of suppressing the extra blank line after
            # multi-line values, which is already in result if translation
            # needed it)
            blanks = -1
          end
        end

        # Check if there are any translations still in strings -- these are
        # extras.  Stick them at end of file in alphabetical order.
        if strings.length > 0
          result += "\n" + ("#" * 80) + "\n\n"
          result += "# Extra/unnecessary translations:\n"
          strings.keys.sort.each do |key|
            result += strings[key]
          end
        end

        # Let user know how many keys were missing, as an "executive summary".
        print "#{filename}: Missing #{missing.keys.length} keys.\n"

        # Write resulting file.
        File.delete("#{filename}.old") if File.exists?("#{filename}.old")
        File.rename(filename, "#{filename}.old")
        File.open(filename, 'w') do |fh|
          fh.write(result)
        end
      end
    end
  end
end
