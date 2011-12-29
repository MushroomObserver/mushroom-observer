# encoding: utf-8
#
#  = Autocompletion Actions
#
#  == Methods
#
#  ajax_auto_complete::           Entry point for all auto-complete requests.
#  ajax_auto_complete_<type>::    Look up matches for a give type, e.g., name, location.
#  refine_auto_complete_string::  Find minimal string whose matches are within limit.
#  refine_auto_complete_words::   Same as above, but words are allowed to be out of order.
#
################################################################################

require 'cgi'

class ApiController
  # Process AJAX request for auto-completion of species name.
  # type::   Type of strings we're auto-completing.
  # letter:: First letter user typed in.
  #
  # Valid types are:
  # name::     Returns Name#text_name starting with the given letter.
  # location:: Returns Observation#where or Location#display_name with a word
  #            starting with the given letter.
  # species_list:: Returns SpeciesList#title starting with the given letter.
  # user::     Returns "login <Full Name>" with a word starting with the given letter.
  #
  # Examples:
  #
  #   /ajax/auto_complete/name/A
  #   /ajax/auto_complete/location/w
  #
  def ajax_auto_complete
    type   = params[:type].to_s
    string = CGI.unescape(params[:id].to_s)
    limit  = 1000  # maximum number of matches allowed

    begin
      string.sub!(/^\s+/, '')
      if !string.empty?
        case type
          when 'name'
            matches = ajax_auto_complete_name(string[0])
            string = refine_auto_complete_string(matches, string, limit)
          when 'location'
            matches = ajax_auto_complete_location(string[0])
            string = refine_auto_complete_words(matches, string, limit)
          when 'project'
            matches = ajax_auto_complete_project(string[0])
            string = refine_auto_complete_words(matches, string, limit)
          when 'species_list'
            matches = ajax_auto_complete_species_list(string[0])
            string = refine_auto_complete_words(matches, string, limit)
          when 'user'
            matches = ajax_auto_complete_user(string[0])
            string = refine_auto_complete_words(matches, string, limit)
          else
            raise "Invalid ajax_auto_complete type: '#{type}'"
        end

        # Truncate list of resulting matches.
        if matches.length > limit
          matches.slice!(limit..-1)
          matches.push('...')
        end

        # Return actual string used to search as first item.
        matches.unshift(string)

        render(:layout => false, :inline => matches.map {|n| n.gsub(/[\r\n].*/,'') + "\n"}.join(''))
      else
        render(:layout => false, :inline => "\n\n")
      end
    rescue => e
      render(:layout => false, :inline => e.to_s, :status => 500)
      # render(:layout => false, :inline => e.to_s + e.backtrace.to_s, :status => 500)
    end
  end

  # Find minimal string whose matches are within the limit.  This is designed
  # to reduce the number of AJAX requests required if the user backspaces from
  # the end of the text field string.
  #
  # The initial query has already matched everything containing a word beginning
  # with the correct first letter.  Applies additional letters one at a time
  # until the number of matches falls below limit.
  #
  # Returns the final (minimal) string actually used, and changes matches in
  # place.  The array 'matches' is guaranteed to be <= limit.
  def refine_auto_complete_string(matches, string, limit)

    # Get rid of trivial case immediately.
    return string[0] if matches.length <= limit

    # Apply characters in order until matches fits within limit.
    used = ''
    for letter in string.split('')
      used += letter
      regex = /(^|[ ,])#{used}/i;
      matches.select! { |m| m.match(regex) }
      break if matches.length <= limit
    end
    return used
  end

  # Same as above, except words are allowed to be out of order.
  def refine_auto_complete_words(matches, string, limit)

    # Get rid of trivial case immediately.
    return string[0] if matches.length <= limit

    # Apply words in order, requiring full word-match on all but last.
    words = string.split
    used  = ''
    n     = 0
    for word in words
      n += 1
      part = ''
      for letter in word.split('')
        part += letter
        regex = /(^|[ ,])#{part}/i;
        matches.select! { |m| m.match(regex) }
        return used + part if matches.length <= limit
      end
      if n < words.length
        used += word + ' '
        regex = /(^|[ ,])#{word}([ ,]|$)/i;
        matches.select! { |m| m.match(regex) }
        return used if matches.length <= limit
      else
        used += word
        return used
      end
    end
  end

  def ajax_auto_complete_name(letter)
    return Name.connection.select_values(%(
      SELECT DISTINCT text_name FROM names
      WHERE text_name LIKE '#{letter}%'
      AND correct_spelling_id IS NULL
    )).sort_by {|x| (x.match(' ') ? 'b' : 'a') + x}.uniq
    # (this sort puts genera and higher on top, everything else
    # on bottom, and sorts alphabetically within each group)
  end

  def ajax_auto_complete_location(letter)
    matches = Observation.connection.select_values(%(
      SELECT DISTINCT `where` FROM observations
      WHERE `where` LIKE '#{letter}%' OR
            `where` LIKE '% #{letter}%'
    )) + Location.connection.select_values(%(
      SELECT DISTINCT `name` FROM locations
      WHERE `name` LIKE '#{letter}%' OR
            `name` LIKE '% #{letter}%'
    ))
    user = login_for_ajax
    if user && user.location_format == :scientific
      matches.map! {|m| Location.reverse_name(m)}
    end
    return matches.sort.uniq
  end

  def ajax_auto_complete_project(letter)
    Project.connection.select_values(%(
      SELECT DISTINCT title FROM projects
      WHERE title LIKE '#{letter}%'
         OR title LIKE '% #{letter}%'
      ORDER BY title ASC
    ))
  end

  def ajax_auto_complete_species_list(letter)
    SpeciesList.connection.select_values(%(
      SELECT DISTINCT title FROM species_lists
      WHERE title LIKE '#{letter}%'
         OR title LIKE '% #{letter}%'
      ORDER BY title ASC
    ))
  end

  def ajax_auto_complete_user(letter)
    User.connection.select_values(%(
      SELECT DISTINCT CONCAT(users.login, IF(users.name = "", "", CONCAT(" <", users.name, ">")))
      FROM users
      WHERE login LIKE '#{letter}%'
         OR name LIKE '#{letter}%'
         OR name LIKE '% #{letter}%'
      ORDER BY login ASC
    ))
  end
end
