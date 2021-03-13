# frozen_string_literal: true

# portion of Name dealing for formatting of Names for display
class Name < AbstractModel
  ##### Display of names #######################################################
  def display_name
    str = self[:display_name]
    if User.current &&
       User.current.hide_authors == :above_species &&
       Name.ranks_above_species.include?(rank)
      str = str.sub(/^(\**__.*__\**).*/, '\\1')
    end
    str
  end

  # Alias for +display_name+ to be consistent with other objects.
  def format_name
    display_name
  end

  # Tack id on to end of +format_name+.
  def unique_format_name
    display_name + " (#{id || "?"})"
  end

  def unique_search_name
    "#{search_name} (#{id || "?"})"
  end

  # (This gives us the ability to format names slightly differently when
  # applied to observations.  For example, we might tack on "sp." to some
  # higher-ranked taxa here.)
  def observation_name
    display_name
  end

  # Marked up Name, authors shortened per ICN Recommendation 46C.2,
  #  e.g.: **__"Xxx yyy__ author1 et al.**
  def display_name_brief_authors
    if rank == :Group
      # Xxx yyy group author
      display_name.sub(/ #{Regexp.quote(author)}$/, " #{brief_author}")
    else
      # Xxx yyy author, Xxx sect. yyy author, Xxx author sect. yyy
      # Relies on display_name having markup around name proper
      # Otherwise, it might delete author if that were part of the name proper
      display_name.sub(/(\*+|_+) #{Regexp.quote(author)}/,
                       "\\1 #{brief_author}")
    end
  end

  # display_name less author
  # This depends on display_name having markup around name proper
  # Otherwise, it might delete author if that were part of the name proper
  def display_name_without_authors
    if rank == :Group
      # Remove author and preceding space at end
      display_name.sub(/ #{Regexp.quote(author)}$/, "")
    else
      # Remove author and preceding space after markup
      display_name.sub(/(\*+|_+) #{Regexp.quote(author)}/, "\\1")
    end
  end

  # Tack id on to end of +text_name+.
  def unique_text_name
    real_text_name + " (#{id || "?"})"
  end

  def real_text_name
    Name.display_to_real_text(self)
  end

  def real_search_name
    Name.display_to_real_search(self)
  end

  def self.display_to_real_text(name)
    name.display_name.gsub(/ ^\*?\*?__ | __\*?\*?[^_*]*$ /x, "").
      gsub(/__\*?\*? [^_*]* \s (#{ANY_NAME_ABBR}) \s \*?\*?__/x, ' \1 ').
      # (this part should be unnecessary)
      # Because "group" was removed by the 1st gsub above,
      # tack it back on (if it was part of display_name)
      gsub(/__\*?\*? [^_*]* \*?\*?__/x, " ").
      concat(group_suffix(name))
  end

  def self.display_to_real_search(name)
    name.display_name.gsub(/\*?\*?__([^_]+)__\*?\*?/, '\1')
  end

  def self.group_suffix(name)
    GROUP_CHUNK.match(name.display_name).to_s
  end

  # Make sure display names are in boldface for accepted names, and not in
  # boldface for deprecated names.
  def self.make_sure_names_are_bolded_correctly
    Name.connection.select_values(%(
      SELECT id FROM names
      WHERE IF(deprecated, display_name LIKE "%*%", display_name NOT LIKE "%*%")
    )).map do |id|
      name = Name.find(id)
      name.change_deprecated(name.deprecated)
      name.save
      "The name #{name.search_name.inspect} " \
      "should #{name.deprecated && "not "} have been in boldface."
    end
  end

  ##### Names treated specially ################################################

  # Array of strings that mean "unknown" in the local language:
  #
  #   "unknown", ""
  #
  def self.names_for_unknown
    ["unknown", :unknown.l, ""]
  end

  # Get an instance of the Name that means "unknown".
  def self.unknown
    Name.find_by(text_name: "Fungi")
  end

  # Is this the "unknown" name?
  def unknown?
    text_name == "Fungi"
  end

  def known?
    !unknown?
  end

  def imageless?
    text_name == "Imageless"
  end

  ##### Miscellaneous ##########################################################

  # Info to include about each name in merge requests.
  def merge_info
    num_obs     = observations.count
    num_namings = namings.count
    num_notify  = interests_plus_notifications
    "#{:NAME.l} ##{id}: #{real_search_name} [#obs: #{num_obs}, " \
      "#namings: #{num_namings}, #users_with_interest: #{num_notify}]"
  end

  def interests_plus_notifications
    interests.count +
      Notification.where(flavor: Notification.flavors[:name], obj_id: id).count
  end

  ##############################################################################

  private

  # author(s) string shortened per ICN Recommendation 46C.2
  # Relies on name.author having a comma only if there are > 2 authors
  def brief_author
    author.sub(/(\(*.),.*\)/, "\\1 et al.)"). # shorten > 2 authors in parens
      sub(/,.*/, " et al.") # then shorten any remaining > 2 authors
  end
end
