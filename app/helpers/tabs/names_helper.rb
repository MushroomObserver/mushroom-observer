# frozen_string_literal: true

module Tabs
  module NamesHelper
    # All action / collection tab definitions migrated to PORO
    # classes under `app/classes/tab/name/*.rb` and callers sweep
    # them directly. The external link tabs below remain here
    # pending a follow-up that migrates them alongside
    # `app/helpers/object_link_helper.rb`'s URL builders.

    # -------- unconverted external link tabs ---------------------

    def external_name_tab(title, name, url, alt_title: nil)
      InternalLink::Model.new(
        title, name, url,
        html_options: { target: :_blank, rel: :noopener },
        alt_title:
      ).tab
    end

    def index_fungorum_search_page_tab
      InternalLink.new(
        :index_fungorum_search.l, index_fungorum_search_page_url,
        html_options: { target: :_blank, rel: :noopener }
      ).tab
    end

    def index_fungorum_record_tab(name)
      external_name_tab("[##{name.icn_id}]", name,
                        index_fungorum_record_url(name.icn_id),
                        alt_title: "index_fungorum_record")
    end

    def mycobank_record_tab(name)
      external_name_tab("[##{name.icn_id}]", name,
                        mycobank_record_url(name.icn_id),
                        alt_title: :mycobank.t)
    end

    def fungorum_gsd_synonymy_tab(name)
      external_name_tab(:gsd_species_synonymy.l, name,
                        species_fungorum_gsd_synonymy(name.icn_id))
    end

    def fungorum_sf_synonymy_tab(name)
      external_name_tab(:sf_species_synonymy.l, name,
                        species_fungorum_sf_synonymy(name.icn_id))
    end

    def mycobank_basic_search_tab
      InternalLink.new(
        :mycobank_search.l, mycobank_basic_search_url,
        html_options: { target: :_blank, rel: :noopener }
      ).tab
    end

    def eol_name_tab(name)
      external_name_tab("EOL", name, name.eol_url)
    end

    def ascomycete_org_name_tab(name)
      external_name_tab("Ascomycete.org", name, ascomycete_org_name_url(name))
    end

    def gbif_name_tab(name)
      external_name_tab("GBIF", name, gbif_name_search_url(name))
    end

    def google_name_tab(name)
      external_name_tab(:google_name_search.l, name,
                        google_name_search_url(name))
    end

    def inat_name_tab(name)
      external_name_tab("iNaturalist", name, inat_name_search_url(name))
    end

    def index_fungorum_name_search_tab(name)
      external_name_tab(:index_fungorum_web_search.l, name,
                        index_fungorum_name_web_search_url(name))
    end

    def ncbi_nucleotide_term_tab(name)
      external_name_tab("NCBI Nucleotide", name,
                        ncbi_nucleotide_term_search_url(name))
    end

    def mushroomexpert_name_tab(name)
      external_name_tab("MushroomExpert", name,
                        mushroomexpert_name_web_search_url(name))
    end

    def wikipedia_term_tab(name)
      external_name_tab("Wikipedia", name, wikipedia_term_search_url(name))
    end

    # -------- non-tab utility ------------------------------------

    def names_index_sorts(query: nil)
      rss_log = query&.params&.dig(:order_by) == :rss_log
      [
        ["name", :sort_by_name.t],
        ["created_at", :sort_by_created_at.t],
        [(rss_log ? "rss_log" : "updated_at"), :sort_by_updated_at.t],
        ["num_views", :sort_by_num_views.t]
      ]
    end
  end
end
