class Name < AbstractModel
  # Alias for +display_name+ to be consistent with other objects.
  def format_name
    display_name
  end

  # Tack id on to end of +text_name+.
  def unique_text_name
    real_text_name + " (#{id || "?"})"
  end

  # Tack id on to end of +format_name+.
  def unique_format_name
    display_name + " (#{id || "?"})"
  end

  # (This gives us the ability to format names slightly differently when
  # applied to observations.  For example, we might tack on "sp." to some
  # higher-ranked taxa here.)
  def observation_name
    display_name
  end

  def real_text_name
    Name.display_to_real_text(self)
  end

  def real_search_name
    Name.display_to_real_search(self)
  end

  def self.display_to_real_text(name)
    name.display_name.gsub(/ ^\*?\*?__ | __\*?\*?[^_\*]*$ /x, "").
      gsub(/__\*?\*? [^_\*]* \s (#{ANY_NAME_ABBR}) \s \*?\*?__/x, ' \1 ').
      gsub(/__\*?\*? [^_\*]* \*?\*?__/x, " "). # (this part should be unnecessary)
      # Because "group" was removed by the 1st gsub above,
      # tack it back on (if it was part of display_name)
      concat(group_suffix(name))
  end

  def self.group_suffix(name)
    GROUP_CHUNK.match(name.display_name).to_s
  end

  def self.display_to_real_search(name)
    name.display_name.gsub(/\*?\*?__([^_]+)__\*?\*?/, '\1')
  end

  # Array of strings that mean "unknown" in the local language:
  #
  #   "unknown", ""
  #
  def self.names_for_unknown
    ["unknown", :unknown.l, ""]
  end

  # Get an instance of the Name that means "unknown".
  def self.unknown
    Name.find_by_text_name("Fungi")
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

  def display_name
    str = self[:display_name]
    if User.current &&
       User.current.hide_authors == :above_species &&
       Name.ranks_above_species.include?(rank)
      str = str.sub(/^(\**__.*__\**).*/, '\\1')
    end
    str
  end

  # Info to include about each name in merge requests.
  def merge_info
    num_obs     = observations.count
    num_namings = namings.count
    "#{:NAME.l} ##{id}: #{real_search_name} [o=#{num_obs}, n=#{num_namings}]"
  end

  # Make sure display names are in boldface for accepted names, and not in
  # boldface for deprecated names.
  def self.make_sure_names_are_bolded_correctly
    msgs = Name.connection.select_values(%(
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
end
