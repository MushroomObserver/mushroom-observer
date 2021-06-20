# frozen_string_literal: true

require("test_helper")

class CuratorTest < IntegrationTestCase
  # ---------- Helpers ----------

  def nybg
    herbaria(:nybg_herbarium)
  end

  # ---------- Tests ----------

  def test_first_herbarium_record
    # Mary doesn't have a herbarium.
    obs = observations(:minimal_unknown_obs)
    login!("mary", "testpassword", true)
    get("/#{obs.id}")
    assert_template("observer/show_observation")
    click(label: :create_herbarium_record.t)
    assert_template("herbarium_record/create_herbarium_record")
    open_form do |form|
      form.submit("Add")
    end
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
  end

  def test_edit_and_remove_herbarium_record_from_show_observation
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    get("/#{obs.id}")
    click(href: "/herbarium_record/edit_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/edit_herbarium_record")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_record/edit_herbarium_record")
    push_page
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
    go_back
    click(label: "Cancel (Show Observation)")
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
    click(href: "/herbarium_record/remove_observation/#{rec.id}")
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_show_herbarium_record
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    get("/#{obs.id}")
    click(href: "/herbarium_record/show_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/show_herbarium_record")
    click(label: "Edit Fungarium Record")
    assert_template("herbarium_record/edit_herbarium_record")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_record/edit_herbarium_record")
    push_page
    click(label: "Cancel (Show Fungarium Record)")
    assert_template("herbarium_record/show_herbarium_record")
    go_back
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("herbarium_record/show_herbarium_record")
    click(label: "Destroy Fungarium Record")
    assert_template("herbarium_record/list_herbarium_records")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_index
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    get(herbarium_path(rec.herbarium.id))
    click(href: /herbarium_index/)
    assert_template("herbarium_record/list_herbarium_records")
    click(href: "/herbarium_record/edit_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/edit_herbarium_record")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_record/edit_herbarium_record")
    push_page
    click(label: "Back to Fungarium Record Index")
    assert_template("herbarium_record/list_herbarium_records")
    go_back
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("herbarium_record/list_herbarium_records")
    click(href: "/herbarium_record/destroy_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/list_herbarium_records")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_index_sort_links
    get(herbaria_path(flavor: :all))

    herbaria_links = assert_select("a:match('href', ?)",
                                   %r{#{herbaria_path}/\d+})
    assert_equal(Herbarium.count, herbaria_links.size,
                 "Index should display links to all herbaria")

    first_herbarium_path = herbaria_links.first.attributes["href"].value.
                           sub(/\?.*/, "") # strip query string

    click(label: :sort_by_reverse.l)
    reverse_herbaria_links = assert_select("a:match('href', ?)",
                                           %r{#{herbaria_path}/\d+})
    assert_equal(
      first_herbarium_path,
      reverse_herbaria_links.last.attributes["href"].value.sub(/\?.*/, ""),
      "Reverse ordered last herbarium should be the normal first herbarium"
    )
  end

  def test_herbarium_index_from_create_herbarium_record
    obs = observations(:minimal_unknown_obs)
    login!("mary", "testpassword", true)
    get("/herbarium_record/create_herbarium_record/#{obs.id}")
    click(label: :herbarium_index.l)

    assert_select(
      "#title-caption", { text: :query_title_nonpersonal.l },
      "Clicking #{:herbarium_index.l} should display " \
      "#{:query_title_nonpersonal.l} by Name"
    )
  end

  def test_single_herbarium_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "New York")
      form.select("type", :HERBARIA.l)
      form.submit("Search")
    end
    assert_select(
      "#title-caption",
      { text: herbaria(:nybg_herbarium).format_name },
      "Fungaria pattern search with a single hit should land on " \
      "the show page for that Fungarium"
    )
  end

  def test_multiple_herbarium_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "Personal")
      form.select("type", :HERBARIA.l)
      form.submit("Search")
    end
    assert_select(
      "#title-caption",
      { text: "Fungaria Matching ‘Personal’" },
      "Fungaria pattern search with multiple hits should land on " \
      "an index page for those Fungaria"
    )
  end

  def test_herbarium_record_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "Coprinus comatus")
      form.select("type", :HERBARIUM_RECORDS.l)
      form.submit("Search")
    end
    assert_template("herbarium_record/list_herbarium_records")
    assert_select(
      "#title-caption",
      { text: "#{:HERBARIUM_RECORDS.l} Matching ‘Coprinus comatus’" },
      "Fungarium Record pattern search should display " \
      "#{:HERBARIUM_RECORDS.l} Matching ‘Coprinus comatus’"
    )
  end

  def test_herbarium_change_code
    herbarium = herbaria(:nybg_herbarium)
    new_code = "NYBG"
    assert_not_equal(new_code, herbarium.code)
    curator = herbarium.curators[0]
    login!(curator.login, "testpassword", true)
    get(edit_herbarium_path(herbarium))
    open_form(
      # The edit form posts to update; this is the update url
      "form[action^='#{herbarium_path(herbarium)}']"
    ) do |form|
      form.assert_value("[code]", herbarium.code)
      form.change("[code]", new_code)
      form.submit(:SAVE.t)
    end

    assert_equal(new_code, herbarium.reload.code)
    assert_select(
      "#title-caption",
      { text: herbarium.format_name },
      "Changing Fungarium code should land on page for that Fungarium"
    )
  end

  def test_herbarium_create_and_destroy
    user = users(:mary)
    assert_equal([], user.curated_herbaria)
    login!(user.login, "testpassword", true)
    get(herbaria_path(flavor: :all))
    click(label: :create_herbarium.l)

    open_form("form[action^='#{herbaria_path}']") do |form|
      form.assert_value("[name]", "")
      form.assert_value("[code]", "")
      form.assert_value("[place_name]", "")
      form.assert_value("[email]", "")
      form.assert_value("[mailing_address]", "")
      form.assert_value("[description]", "")
      form.assert_unchecked("[personal]")

      form.change("[name]", "Mary's Herbarium")
      form.check("[personal]")
      form.submit(:CREATE.l)
    end
    user = User.find(user.id)
    assert_not_empty(user.curated_herbaria)

    assert_select(
      "#title-caption", { text: "Mary’s Herbarium" }, # smart apostrophe
      "Creating a Fungarium should show the new Fungarium"
    )

    # looks like a link, but is really a button
    open_form("form[action^='#{herbarium_path(Herbarium.last)}']") do |form|
      form.submit(:destroy_object.t(type: :herbarium))
    end
    assert_select(
      "#title-caption", { text: :herbarium_index.l },
      "Destroying a Fungarium should display #{:herbarium_index.l}"
    )
  end

  def test_add_curator
    # Make sure nobody broke the fixtures
    assert(nybg.curators.include?(roy),
           "Need different fixture: herbarium where roy is a curator")
    assert(nybg.curators.exclude?(mary),
           "Need different fixture: herbarium where mary is not a curator")

    # add mary as a curator
    login!(roy.login, "testpassword", true)
    get(herbarium_path(nybg))
    open_form("form[action^='#{herbaria_curators_path(id: nybg)}']") do |form|
      form.change("add_curator", mary.login)
      form.submit("Add Curator")
    end

    assert(nybg.curator?(mary),
           "Failed to add mary to curators of #{nybg.format_name}")
    assert_select(
      "form[action^='#{herbaria_curator_path(nybg, user: mary.id)}']"
    ) do
      assert_select("input[value='delete']", true,
                    "Page is missing a button to remove Mary as curator")
    end
  end

  def test_curator_request
    # Make sure noone broke the fixtures
    assert(nybg.curators.exclude?(mary),
           "Need different fixture: herbarium that mary does not curate")

    login!("mary", "testpassword", true)
    get(herbarium_path(nybg))
    click(label: :show_herbarium_curator_request.l)
    assert_select("#title-caption").text.
      starts_with?(:show_herbarium_curator_request.l)
    open_form("form[action^='#{herbaria_curator_requests_path(id: nybg)}']",
              &:submit)

    assert_flash_text(:show_herbarium_request_sent.t)
    assert_select(
      "#title-caption", { text: nybg.format_name },
      "Submitting a curator request should return to herbarium page"
    )
  end

  def test_merge
    fundis = herbaria(:fundis_herbarium)
    assert_true(fundis.owns_all_records?(mary),
                "Need different fixture: #{mary.name} must own all records")
    mary_herbarium = mary.create_personal_herbarium

    login!("mary", "testpassword", true)
    get(herbaria_path(flavor: :all))
    click(href: herbaria_path(merge: fundis))
    form = open_form( # merge button
      "form[action *= 'dest=#{mary_herbarium.id}']"
    )
    form.submit("#{mary.name} (#{mary.login}): Personal Fungarium")

    assert_response(:success) # Rails follows the redirect
    assert_select("#title-caption", text: :herbarium_index.l)
  end
end
