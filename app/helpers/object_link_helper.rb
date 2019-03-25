# helpers for creating links in views
module ObjectLinkHelper
  # Dictionary of urls for searches on external sites
  LOCATION_SEARCH_URLS = {
    Google_Maps: "https://maps.google.com/maps?q=",
    Google_Search: "https://www.google.com/search?q=",
    Wikipedia: "https://en.wikipedia.org/w/index.php?search="
  }.freeze

  # Wrap location name in span: "<span>where (count)</span>"
  #
  #   Where: <%= where_string(obs.place_name) %>
  #
  def where_string(where, count = nil)
    result = where.t
    result += " (#{count})" if count
    content_tag(:span, result, class: "Data")
  end

  # Wrap location name in link to show_location / observations_at_where.
  #
  #   Where: <%= location_link(obs.where, obs.location) %>
  #
  def location_link(where, location, count = nil, click = false)
    if location
      location = Location.find(location) unless location.is_a?(AbstractModel)
      link_string = where_string(location.display_name, count)
      link_string += " [#{:click_for_map.t}]" if click
      link_to(link_string, location.show_link_args)
    else
      link_string = where_string(where, count)
      link_string += " [#{:SEARCH.t}]" if click
      link_to(link_string, controller: :observer,
                           action: :observations_at_where, where: where)
    end
  end

  # Wrap name in link to show_name.
  #
  #   Parent: <%= name_link(name.parent) %>
  #
  def name_link(name, str = nil)
    if name.is_a?(Integer)
      str ||= :NAME.t + " #" + name.to_s
      link_to(str, Name.show_link_args(name))
    else
      str ||= name.display_name.t
      link_to(str, name.show_link_args)
    end
  end

  # Create link for name to MyCoPortal website.
  def mycoportal_url(name)
    "http://mycoportal.org/portal/taxa/index.php?taxauthid=1&taxon=" +
      name.text_name.tr(" ", "+")
  end

  # Create link for name to search in MycoBank
  def mycobank_url(name)
    unescaped_str = (mycobank_path + mycobank_taxon(name) +
                     mycobank_language_suffix(locale).to_s)
    # CGI::escape.html(unescaped_str) should work, but throws error
    #   ActionView::Template::Error: wrong number of arguments (0 for 1)
    unescaped_str.gsub(" ", "%20")
  end

  def mycobank_path
    "http://www.mycobank.org/name/"
  end

  def mycobank_taxon(name)
    name.between_genus_and_species? ? name.text_before_rank : name.text_name
  end

  # language parameter for MycoBank link
  # input is I18n language abbreviation
  # return html parameter of official Mycobank translation,
  # if such translation exists, else return pseudo-English parameter
  # Although MycoBank doesn't recognize &Lang=Eng, this (or another language
  # parameter else which MycoBank does not recognize) must be be included when
  # switching to the default MycoBank language (English); otherwise MycoBank
  # keeps using the last language it did recognize.
  def mycobank_language_suffix(lang)
    "&Lang=" + i18n_to_mycobank_language.fetch(lang, "Eng")
  end

  # hash of i18n languages => Mycobank official translation languages
  def i18n_to_mycobank_language
    { de: "Deu", es: "Spa", fr: "Fra", pt: "Por",
      ar: "Ara", fa: "Far", nl: "Nld", th: "Tha", zh: "Zho" }
  end

  # Wrap user name in link to show_user.
  #
  #   Owner:   <%= user_link(name.user) %>
  #   Authors: <%= name.authors.map(&:user_link).join(", ") %>
  #
  #   # If you don't have a full User instance handy:
  #   Modified by: <%= user_link(login, user_id) %>
  #
  def user_link(user, name = nil)
    if user.is_a?(Integer)
      name ||= :USER.t + " #" + user.to_s
      link_to(name, User.show_link_args(user))
    elsif user
      name ||= user.unique_text_name
      link_to(name, user.show_link_args)
    else
      "?"
    end
  end

  # Render a list of users on one line.  (Renders nothing if user list empty.)
  # This renders the following strings:
  #
  #   <%= user_list("Author", name.authors) %>
  #
  #   empty:           ""
  #   [bob]:           "Author: Bob"
  #   [bob,fred,mary]: "Authors: Bob, Fred, Mary"
  #
  def user_list(title, users = [])
    return safe_empty unless users&.any?

    title = users.count > 1 ? title.to_s.pluralize.to_sym.t : title.t
    links = users.map { |u| user_link(u, u.legal_name) }
    title + ": " + links.safe_join(", ")
  end

  # Wrap object's name in link to the object, return nil if no object
  #   Project: <%= project_link(draft_name.project) %>
  #   Species List: <%= species_list_link(observation.species_lists.first) %>
  def link_to_object(object, name = nil)
    return nil unless object

    link_to(name || object.title.t, object.show_link_args)
  end

  # Wrap description title in link to show_description.
  #
  #   Description: <%= description_link(name.description) %>
  #
  def description_link(desc)
    result = description_title(desc)
    return result if result.match?("(#{:private.t})$")

    link_with_query(result, desc.show_link_args)
  end

  # Array of links to searches on external sites;
  # Shown on create/edit location pages
  def location_search_links(name)
    search_string = name.gsub(" Co.", " County").gsub(", USA", "").
                    tr(" ", "+").gsub(",", "%2C")
    LOCATION_SEARCH_URLS.each_with_object([]) do |site, link_array|
      link_array << search_link_to(site.first, search_string)
    end
  end

  def search_link_to(site_symbol, search_string)
    return unless (url = LOCATION_SEARCH_URLS[site_symbol])

    link_to(site_symbol.to_s.titlecase, url << search_string)
  end

  def add_sequence_link(obs)
    return nil unless check_permission(obs)

    link = link_with_query(:show_observation_add_sequence.t,
                           controller: :sequence, action: :create_sequence,
                           id: obs.id)
    " | ".html_safe + link
  end

  def observation_herbarium_record_link(obs)
    count = obs.herbarium_records.count
    if count.positive?
      link_to(pluralize(count, :herbarium_record.t),
              controller: :herbarium_record, action: :observation_index,
              id: obs.id)
    else
      return :show_observation_specimen_available.t if obs.specimen

      :show_observation_specimen_not_available.t
    end
  end
end
