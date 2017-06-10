#  = External Link Helpers
#
# Helpers for view links to external websites
# Ideally, all those links go through this helper to keep them consisent,
#   reusable, and DRY
#
################################################################################
#
module ExternalLinkHelper
  ##### EOL (Encyclopedia of Life) #####
  #
  # Create link which results in an EOL search for named taxon
  # Note: args are reversed from link_to, so that link_text can be optional
  def link_to_eol_search(name, link_text = "EOL")
    link_to(link_text, name.eol_url, target: "_blank")
  end

  ##### GoogleImages #####
  #
  # Create link which results in a Google search for images of name
  # Note: args are reversed from link_to, so that link_text can be optional
  def link_to_google_images_search(name, link_text = :google_images.t)
    link_to(link_text,
            "http://images.google.com/images?q=#{name.real_text_name}",
            target: "_blank")
  end

  ##### MycoBank (nomenclature) #####
  #
  # Create link which results in a MycoBank search for name
  # Note: args are reversed from link_to, so that link_text can be optional
  def link_to_mycobank_search(name, link_text = "MycoBank")
    link_to(link_text,
            mycobank_path + mycobank_taxon(name) +
              mycobank_language_suffix(locale).to_s,
            target: "_blank")
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
  # parameter which MycoBank does **not** recognize) must be be included when
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

  ##### MycoPortal (herbarium portal) #####
  # Create link for name to MycoPortal website.
  def link_to_mycoportal_search(name, link_text = "MycoPortal")
    link_to(link_text,
            "http://mycoportal.org/portal/taxa/index.php?taxauthid=1&taxon=" +
              name.text_name.tr(" ", "+"),
            target: "_blank")
  end
end
