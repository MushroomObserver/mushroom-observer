namespace :lang do

  desc "Re-sort translations according to English one, filling in missing ones, and moving extras to the end."
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
        comments_at_top = ''
        strings = {}
        dups = {}
        undone = {}
        File.open(filename) do |fh|
          key = nil
          at_top = true
          fh.each_line do |line|
            line.sub!(/^\xEF\xBB\xBF/, '')  # (remove stupid UTF-8 marker)
            if line.match(/^#\s*----/)
              at_top = false
            elsif at_top
              comments_at_top += line
            elsif line.match(/^(\w+):(\s+)/)
              key = $1
              # Keep track of things that haven't been translated yet.
              undone[key] = true if $2.length > 1
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

        # Clean up translations: remove excess trailing whitespace.
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
        result = comments_at_top
        result.sub!(/\n+\Z/, "\n\n")
        result += "# ----- COMMENTS BELOW THIS WILL BE DESTROYED -----\n\n"
        blanks = 0
        missing = {}
        keys_in_english = {}
        for line in template
          # Comment: assume this ends previous value.
          if line.match(/^#/)
            result += "\n" * blanks if blanks > 0
            result += line
            blanks = 0
            doing_missing = false
          # Blank line: hold on to these until we know what to do with them.
          elsif !line.match(/\S/)
            blanks += 1
          # New key: if recognized insert translation, else copy English one.
          elsif line.match(/^(\w+):/)
            key = $1
            # (check for duplicates in English translation, too)
            if keys_in_english[key]
              print "Duplicate key in English: #{key}\n" if !dups_in_english[key]
              dups_in_english[key] = true
            end
            keys_in_english[key] = true
            result += "\n" * blanks if blanks > 0
            # Only keep translations, throw away ones not translated yet.
            if strings[key] && !undone[key]
              result += strings[key]
              strings.delete(key)
              doing_missing = false
            else
              # (use two spaces after colon for missing translations)
              result += line.sub(/:\s*/, ':  ')
              missing[key] = true
              doing_missing = true
              # (Untranslated keys will still be in strings. Remove them or
              # they will get written again at the bottom as an "unneeded"
              # translation.  Better make sure your translations have that
              # second space removed or this will clobber them!!!)
              strings.delete(key) if strings.has_key?(key)
            end
            blanks = 0
          # All other lines must be "folded lines" from "key: >" constructs.
          elsif doing_missing
            result += "\n" * blanks if blanks > 0
            result += line
            blanks = 0
          else
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
