# frozen_string_literal: true

require("test_helper")

class NamesControllerShowTest < FunctionalTestCase
  tests NamesController

  ################################################
  #
  #   SHOW
  #
  ################################################

  def test_show_name
    # assert_equal(0, QueryRecord.count)
    login
    get(:show, params: { id: names(:coprinus_comatus).id })
    assert_select("#nomenclature")
    # Creates three for children and all four observations sections,
    # but one never used. (? Now 4 - AN 20240107) (? Now 5 - AN 20241217)
    # assert_equal(5, QueryRecord.count)

    get(:show, params: { id: names(:coprinus_comatus).id })
    assert_select("#nomenclature")
    # Should re-use all the old queries.
    # assert_equal(5, QueryRecord.count)

    get(:show, params: { id: names(:agaricus_campestris).id })
    assert_select("#nomenclature")
    # Needs new queries this time.
    # (? Up from 7 to 9 - AN 20240107)
    # Why are we making this assertion if we don't know what the
    # value should be?
    # assert_equal(9, QueryRecord.count)

    # Agarcius: has children taxa.
    get(:show, params: { id: names(:agaricus).id })
    assert_select("#nomenclature")
  end

  # Regression for #4491: name text (author, synonyms, classification
  # rows) is textile-safe HTML. The Phlex conversion emitted it via
  # `plain`, which re-escaped the entities, so panels showed literal
  # codes like "&amp;" / "&#8212;" instead of "&" / "—". Same root cause
  # / fix (`trusted_html`) in the nomenclature and classification panels.
  def test_show_name_renders_html_entities_not_codes
    login
    # author is "(Bull.) Vilgalys, Hopple & Jacq. Johnson"
    name = names(:coprinellus_micaceus)
    get(:show, params: { id: name.id })
    assert_response(:success)

    nomenclature = css_select("#nomenclature").text
    assert_includes(nomenclature, "Hopple & Jacq. Johnson",
                    "ampersand should render as a character, not a code")
    assert_not_includes(nomenclature, "&amp;",
                        "HTML entity codes should not be visible as text")
  end

  def test_show_name_species_with_icn_id
    # Name's icn_id is filled in
    name = names(:coprinus_comatus)
    icn_id = name.icn_id
    assert_instance_of(Integer, icn_id,
                       "Test needs Name fixture with icn_id (Registration #)")
    assert_not(name.classification =~ /Ascomycete/,
               "Test needs a Name fixture which isn't an Ascomycete")

    login
    get(:show, params: { id: name.id })

    ##### External research links
    [
      ["GBIF", Tab::Name::Gbif.new(name: name).path],
      ["Google Search", Tab::Name::GoogleSearch.new(name: name).path],
      ["iNat", Tab::Name::Inat.new(name: name).path],
      ["MushroomExpert", Tab::Name::MushroomExpert.new(name: name).path],
      ["MyCoPortal", Tab::Name::Mycoportal.new(name: name).path],
      ["NCBI", Tab::Name::NcbiNucleotide.new(name: name).path],
      ["Wikipedia", Tab::Name::Wikipedia.new(name: name).path]
    ].each do |site, link|
      assert_external_link(site, link)
    end

    assert_select(
      "body a[href='#{Tab::Name::AscomyceteOrg.new(name: name).path}']", false,
      "Page should not have a link to Ascomycete.org"
    )

    ##### External nomenclature links
    [
      ["IF record", Tab::Name::IndexFungorumRecord.new(name: name).path],
      ["MB record", Tab::Name::MycobankRecord.new(name: name).path],
      ["GSD Synonymy record",
       Tab::Name::FungorumGsdSynonymy.new(name: name).path]
    ].each do |site, link|
      assert_external_link(site, link)
    end
  end

  def assert_external_link(site, link)
    assert_select(
      "body a[href='#{link}']", true,
      "Page is missing a link to #{site}"
    )
  end

  def test_show_name_ascomycete
    name = names(:peltigera)
    assert_match(/Ascomycete/, name.classification,
                 "Test needs a Name fixture that's an Ascomycete")

    login
    get(:show, params: { id: name.id })

    assert_external_link("Ascomycete.org",
                         Tab::Name::AscomyceteOrg.new(name: name).path)
  end

  def test_show_name_genus_with_icn_id
    # Name's icn_id is filled in
    name = names(:tubaria)
    login
    get(:show, params: { id: name.id })
    assert_select(
      "body a[href='#{Tab::Name::FungorumSfSynonymy.new(name: name).path}']",
      true,
      "Page is missing a link to SF Synonymy record"
    )
  end

  def test_show_name_icn_id_missing
    # Name is registrable, but icn_id is not filled in
    name = names(:coprinus)
    label = :icn_id.ti.to_s

    login
    get(:show, params: { id: name.id })

    assert_select(
      "#nomenclature", /#{label}.*#{:show_name_icn_id_missing.l}/m,
      "Nomenclature section missing an ICN id label and/or " \
      "'#{:show_name_icn_id_missing.l}' note"
    )
    assert_select(
      "#nomenclature a:match('href',?)",
      /#{Tab::Name::IndexFungorumSearchPage.new.path}/,
      { count: 1 },
      "Nomenclature section is missing a link to IF search page"
    )
    assert_select(
      "#nomenclature " \
      "a[href='#{Tab::Name::IndexFungorumNameSearch.new(name: name).path}']",
      true,
      "Nomenclature section is missing a link to Index Fungorum web search"
    )
    assert_select(
      "#nomenclature a:match('href',?)",
      /#{Tab::Name::MycobankSearch.new(name: name).path}/,
      { count: 1 },
      "Nomenclature section should have link to MB search"
    )

    assert_select(
      "body a[href='#{Tab::Name::IndexFungorumRecord.new(name: name).path}']",
      false,
      "Page should not have link to IF record"
    )
  end

  def test_show_name_searchable_in_registry
    name = names(:boletus_edulis_group)
    login
    get(:show, params: { id: name.id })

    # Name isn't registrable; it shouldn't have an icn_id label or record link
    assert(/#{:icn_id.ti}/ !~ @response.body,
           "Page should not have ICN identifier label")
    assert_select(
      "body a[href='#{Tab::Name::IndexFungorumRecord.new(name: name).path}']",
      false,
      "Page should not have link to IF record"
    )

    # but it makes sense to link to search pages in fungal registries
    assert_select(
      "#nomenclature a:match('href',?)",
      /#{Tab::Name::IndexFungorumSearchPage.new.path}/,
      { count: 1 },
      "Nomenclature section should have link to IF search page"
    )
    assert_select(
      "#nomenclature " \
      "a[href='#{Tab::Name::IndexFungorumNameSearch.new(name: name).path}']",
      true,
      "Nomenclature section is missing a link to Index Fungorum web search"
    )
    assert_select(
      "#nomenclature a:match('href',?)",
      /#{Tab::Name::MycobankBasicSearch.new.path}/,
      { count: 1 },
      "Nomenclature section should have link to MB search"
    )
  end

  def test_show_name_icn_id_unregistrable
    # Name is not registrable (cannot have an icn number)
    name = names(:eukarya)
    login
    get(:show, params: { id: name.id })
    assert(/#{:icn_id.ti}/ !~ @response.body,
           "Page should not have ICN identifier label")
  end

  def test_show_name_with_eol_link
    login
    get(:show, params: { id: names(:abortiporus_biennis_for_eol).id })
    assert_select("#nomenclature")
  end

  def test_citation_url_renders_as_link
    url = "http://example.com/protologue"
    name = names(:peltigera)

    name.update!(citation: url)
    login
    get(:show, params: { id: name.id })
    assert_select(
      "#nomenclature a[href='#{url}']",
      { count: 1 },
      "Bare URL citation should render as a clickable link"
    )

    name.update!(citation: "\"Protologue\":#{url}")
    get(:show, params: { id: name.id })
    assert_select(
      "#nomenclature a[href='#{url}']",
      { text: "Protologue", count: 1 },
      "Textile-style citation should render as a link with correct text"
    )
  end

  def test_name_external_links_exist
    login
    get(:show, params: { id: names(:coprinus_comatus).id })

    assert_select("a[href *= 'images.google.com']")
    assert_select("a[href *= 'mycoportal.org']")
  end

  # Regression: the Occurrence Map link in the show page's tabs
  # should never inherit `q[in_box]` (or any other query context)
  # from the URL the user arrived on. Otherwise navigating
  # "name → name → occurrence map" silently restricts the map to
  # whatever spatial filter happened to be in scope (#4139).
  def test_occurrence_map_tab_strips_in_box_query_context
    login
    name = names(:coprinus_comatus)
    get(:show, params: {
          id: name.id,
          q: { in_box: { north: 40, south: 30, east: -70, west: -80 },
               model: "Observation" }
        })

    assert_select(
      "a[href*='/names/#{name.id}/map']", { minimum: 1 }
    ) do |links|
      links.each do |link|
        href = link["href"]
        assert_no_match(/in_box/, href,
                        "Occurrence Map tab link must not inherit " \
                        "in_box from the URL's query context " \
                        "(href=#{href.inspect})")
      end
    end
  end

  def test_show_name_locked
    name = Name.where(locked: true).first
    # login
    # get(:show, params: { id: name.id })
    # assert_synonym_links(name, 0, 0, 0)
    login(rolf.login)
    get(:show, params: { id: name.id })
    assert_synonym_links(name, 0, 0, 0)
    make_admin(mary.login)
    get(:show, params: { id: name.id })
    assert_synonym_links(name, 0, 1, 1)

    name.current_user = users(:rolf)
    name.deprecated = true
    name.save
    logout
    get(:show, params: { id: name.id })
    assert_synonym_links(name, 0, 0, 0)
    login(rolf.login)
    get(:show, params: { id: name.id })
    assert_synonym_links(name, 0, 0, 0)
    make_admin(mary.login)
    get(:show, params: { id: name.id })
    assert_synonym_links(name, 1, 0, 1)
  end

  def test_show_missing_created_at
    name = names(:coprinus_comatus)

    footer_created_by =
      # I'd like to do something like the commented out lines,
      # but they thhrow an error at
      # app/helpers/object_link_helper.rb:124:in `user_link'
      # footer_created_by = :footer_created_by.t(
      #   user: user_link(name.user),
      #   date: name.created_at.web_time
      # ).to_s
      "<strong>Created:</strong> #{name.created_at.web_time} " \
      "<strong>by</strong> #{name.user.name} (#{name.user.login}"

    # zap created_at directly in the db, else Rails will also change updated_at
    name.update_columns(created_at: nil)

    login
    get(:show, params: { id: name.id })

    assert_no_match(
      footer_created_by, @response.body,
      "Footer should omit `#{:created.ti} line if created_at is absent"
    )
  end

  def test_show_new_version_missing_updated_at
    name = names(:coprinus_comatus)
    assert_operator(name.version, :>, 1,
                    "Test needs a fixture with multiple versions")
    footer_updated_at =
      :footer_last_updated_at.t(date: name.updated_at.web_time).to_s

    # bork updated_at directly in the db, else Rails will add it
    name.update_columns(updated_at: nil)
    login
    get(:show, params: { id: name.id })

    assert_no_match(
      footer_updated_at, @response.body,
      "Footer should omit #{:modified.l} date if updated_at absent"
    )
  end

  def test_show_new_version_missing_user
    name = names(:coprinus_comatus)
    name_last_version = name.versions.last
    assert_operator(name_last_version.version, :>, 1,
                    "Test needs a fixture with multiple versions")
    last_user = User.find(name_last_version.user_id)
    footer_last_updated_by =
      # I'd like to do something like the commented out lines,
      # but they thhrow an error at
      #    app/helpers/object_link_helper.rb:124:in `user_link'
      # -- jdc 2023-05-17
      # (:footer_last_updated_by.t(
      #    user: user_link(last_user),
      #    date: name_last_version.updated_at.web_time)
      # ).to_s
      "<strong>Last modified:</strong> " \
      "#{name_last_version.updated_at.web_time} " \
      "<strong>by</strong> #{last_user.name} (#{last_user.login})"

    # bork user directly in the db, else Rails will also change updated_at
    name_last_version.update_columns(user_id: nil)

    login
    get(:show, params: { id: name.id })

    assert_no_match(
      footer_last_updated_by, @response.body,
      "Footer should omit #{:modified.l} by if updated_at absent"
    )
  end

  def test_show_name_inherit_link
    name = names(:pasaria)
    assert(!name.below_genus? && name.classification.blank?,
           "Need fixture with rank >= Genus and lacking Classification")

    login
    get(:show, params: { id: name.id })

    assert_select(
      "#name_classification",
      { text: /#{:show_name_inherit_classification.l}/, count: 1 },
      "Classification area lacks a #{:show_name_inherit_classification.l} link"
    )
  end

  def test_show_name_sensu_lato
    name = names(:coprinus_sensu_lato)
    assert(name.rank == "Genus" && name.author.match?(/sensu lato/) &&
             name.classification.present?,
           "Test needs Genus sensu lato with a Classification")

    login
    get(:show, params: { id: name.id })

    assert_select(
      "#name_classification",
      { text: /#{:show_name_propagate_classification.l}/, count: 0 },
      "Name sensu lato should not have propagate classification link"
    )
  end

  def assert_synonym_links(name, approve, deprecate, edit)
    assert_select("a[href*=?]", form_to_approve_synonym_of_name_path(name.id),
                  count: approve)
    assert_select("a[href*=?]", form_to_deprecate_synonym_of_name_path(name.id),
                  count: deprecate)
    assert_select("a[href*=?]", edit_synonyms_of_name_path(name.id),
                  count: edit)
  end

  # ----------------------------
  #  Interest.
  # ----------------------------

  # NOTE: The interest links are GET paths because email.
  def test_interest_in_show_name
    peltigera = names(:peltigera)
    login(rolf.login)

    # No interest in this name yet.
    get(:show, params: { id: peltigera.id })
    assert_response(:success)
    assert_image_link_in_html(/watch.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: 1))
    assert_image_link_in_html(/ignore.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: -1))

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.create(target: peltigera, user: rolf, state: true)
    get(:show, params: { id: peltigera.id })
    assert_response(:success)
    assert_image_link_in_html(/halfopen.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: 0))
    assert_image_link_in_html(/ignore.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: -1))

    # Destroy that interest, create new one with interest off.
    Interest.where(user_id: rolf.id).last.destroy
    Interest.create(target: peltigera, user: rolf, state: false)
    get(:show, params: { id: peltigera.id })
    assert_response(:success)
    assert_image_link_in_html(/halfopen.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: 0))
    assert_image_link_in_html(/watch.*\.png/,
                              set_interest_path(type: "Name",
                                                id: peltigera.id, state: 1))
  end

  def test_next_and_prev
    names = Name.order(:sort_name).to_a
    name12 = names[12]
    name13 = names[13]
    name14 = names[14]
    login
    get(:show, params: { flow: :next, id: name12.id })
    params = { q: @controller.q_param(QueryRecord.last.query) }

    assert_redirected_to(name_path(name13.id, params:))
    get(:show, params: { flow: :next, id: name13.id })
    assert_redirected_to(name_path(name14.id, params:))
    get(:show, params: { flow: :prev, id: name14.id })
    assert_redirected_to(name_path(name13.id, params:))
    get(:show, params: { flow: :prev, id: name13.id })
    assert_redirected_to(name_path(name12.id, params:))
  end

  def test_next_and_prev2
    query = Query.lookup_and_save(:Name, pattern: "lactarius")
    params = { q: @controller.q_param(query) }

    name1 = query.results[0]
    name2 = query.results[1]
    name3 = query.results[-2]
    name4 = query.results[-1]

    login
    get(:show, params: params.merge(id: name1.id, flow: :next))
    assert_redirected_to(name_path(name2.id, params:))
    get(:show, params: params.merge(id: name3.id, flow: :next))
    assert_redirected_to(name_path(name4.id, params:))
    get(:show, params: params.merge(id: name4.id, flow: :next))
    assert_redirected_to(name_path(name4.id, params:))
    assert_flash_text(/no more/i)

    get(:show, params: params.merge(id: name4.id, flow: :prev))
    assert_redirected_to(name_path(name3.id, params:))
    get(:show, params: params.merge(id: name2.id, flow: :prev))
    assert_redirected_to(name_path(name1.id, params:))
    get(:show, params: params.merge(id: name1.id, flow: :prev))
    assert_redirected_to(name_path(name1.id, params:))
    assert_flash_text(/no more/i)
  end
end
