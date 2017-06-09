#  = External Link Helpers
#
# Helpers for view links to external websites
# Ideally, all those links go through this helper to keep them consisent,
#   resuable, and DRY
#
################################################################################
#
module ExternalLinkHelper
  # Create link for name to MyCoPortal website.
  def mycoportal_url(name)
    "http://mycoportal.org/portal/taxa/index.php?taxauthid=1&taxon=" +
      name.text_name.tr(" ", "+")
  end

  ##### MycoBank (nomenclature) #####
  #
  # Create link which result in a MycoBank search for name
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
end
