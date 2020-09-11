# frozen_string_literal: true

require("test_helper")

class NameControllerTest < FunctionalTestCase
  def self.report_email(email)
    @@emails << email
  end

  def setup
    @new_pts  = 10
    @chg_pts  = 10
    @auth_pts = 100
    @edit_pts = 10
    @@emails = []
    super
  end

  def empty_notes
    NameDescription.all_note_fields.each_with_object({}) do |field, result|
      result[field] = ""
    end
  end

  CREATE_NAME_DESCRIPTION_PARTIALS = %w[
    _form_description
    _textilize_help
    _form_name_description
  ].freeze

  SHOW_NAME_DESCRIPTION_PARTIALS = %w[
    _show_description
    _name_description
  ].freeze

  # Create a draft for a project.
  def create_draft_tester(project, name, user = nil, success = true)
    count = NameDescription.count
    params = {
      id: name.id,
      source: "project",
      project: project.id
    }
    requires_login(:create_name_description, params, user.login)
    if success
      assert_template(:create_name_description,
                      partial: "_form_name_description")
    else
      assert_redirected_to(controller: "project", action: "show_project",
                           id: project.id)
    end
    assert_equal(count, NameDescription.count)
  end

  # Edit a draft for a project (GET).
  def edit_draft_tester(draft, user = nil, success = true, reader = true)
    if user
      assert_not_equal(user, draft.user)
    else
      user = draft.user
    end
    params = {
      id: draft.id
    }
    requires_login(:edit_name_description, params, user.login)
    if success
      assert_template(:edit_name_description, partial: "_form_name_description")
    elsif reader
      assert_redirected_to(action: :show_name_description, id: draft.id)
    else
      assert_redirected_to(action: :show_name, id: draft.name_id)
    end
  end

  # Edit a draft for a project (POST).
  def edit_draft_post_helper(draft, user, params: {}, permission: true,
                             success: true)
    gen_desc = "This is a very general description."
    assert_not_equal(gen_desc, draft.gen_desc)
    diag_desc = "This is a diagnostic description"
    assert_not_equal(diag_desc, draft.diag_desc)
    classification = "Family: _Agaricaceae_"
    assert_not_equal(classification, draft.classification)
    params = {
      id: draft.id,
      description: {
        gen_desc: gen_desc,
        diag_desc: diag_desc,
        classification: classification
      }.merge(params)
    }
    post_requires_login(:edit_name_description, params, user.login)
    if permission && !success
      assert_template(:edit_name_description, partial: "_form_name_description")
    elsif draft.is_reader?(user)
      assert_redirected_to(action: :show_name_description, id: draft.id)
    else
      assert_redirected_to(action: :show_name, id: draft.name_id)
    end

    draft.reload
    if permission && success
      assert_equal(gen_desc, draft.gen_desc)
      assert_equal(diag_desc, draft.diag_desc)
      assert_equal(classification, draft.classification)
    else
      assert_not_equal(gen_desc, draft.gen_desc)
      assert_not_equal(diag_desc, draft.diag_desc)
      assert_not_equal(classification, draft.classification)
    end
  end

  def publish_draft_helper(draft, user = nil, merged = true, conflict = false)
    if user
      assert_not_equal(draft.user, user)
    else
      user = draft.user
    end
    draft_gen_desc = draft.gen_desc
    name_gen_desc = begin
                      draft.name.description.gen_desc
                    rescue StandardError
                      nil
                    end
    same_gen_desc = (draft_gen_desc == name_gen_desc)
    name_id = draft.name_id
    params = {
      id: draft.id
    }
    requires_login(:publish_description, params, user.login)
    name = Name.find(name_id)
    new_gen_desc = begin
                     name.description.gen_desc
                   rescue StandardError
                     nil
                   end
    if merged
      assert_equal(draft_gen_desc, new_gen_desc)
    else
      assert_equal(same_gen_desc, draft_gen_desc == new_gen_desc)
      assert(NameDescription.safe_find(draft.id))
    end
    if conflict
      assert_template(:edit_name_description, partial: true)
      assert(assigns(:description).gen_desc.index(draft_gen_desc))
      assert(assigns(:description).gen_desc.index(name_gen_desc))
    else
      assert_redirected_to(action: :show_name, id: name_id)
    end
  end

  def make_description_default_helper(desc)
    user = desc.user
    params = {
      id: desc.id
    }
    requires_login(:make_description_default, params, user.login)
  end

  # Destroy a draft of a project.
  def destroy_draft_helper(draft, user, success = true)
    assert(draft)
    count = NameDescription.count
    params = {
      id: draft.id
    }
    requires_login(:destroy_name_description, params, user.login)
    if success
      assert_redirected_to(action: :show_name, id: draft.name_id)
      assert_raises(ActiveRecord::RecordNotFound) do
        draft = NameDescription.find(draft.id)
      end
      assert_equal(count - 1, NameDescription.count)
    else
      assert(NameDescription.find(draft.id))
      assert_equal(count, NameDescription.count)
      if draft.is_reader?(user)
        assert_redirected_to(action: :show_name_description, id: draft.id)
      else
        assert_redirected_to(action: :show_name, id: draft.name_id)
      end
    end
  end

  def assert_email_generated
    assert_not_empty(@@emails, "Was expecting an email notification.")
  ensure
    @@emails = []
  end

  def assert_no_emails
    msg = @@emails.join("\n")
    assert(@@emails.empty?,
           "Wasn't expecting any email notifications; got:\n#{msg}")
  ensure
    @@emails = []
  end

  def create_name(name)
    parse = Name.parse_name(name)
    Name.new_name(parse.params)
  end

  def test_index_name
    get_with_dump(:index_name)
    assert_template(:list_names)
  end

  def test_name_index
    get_with_dump(:list_names)
    assert_template(:list_names)
  end

  def test_name_description_index
    get_with_dump(:list_name_descriptions)
    assert_template(:list_name_descriptions)
  end

  def test_index_description_index
    get_with_dump(:index_name_description)
    assert_template(:list_name_descriptions)
  end

  def test_observation_index
    get_with_dump(:observation_index)
    assert_template(:list_names)
  end

  def test_observation_index_by_letter
    get_with_dump(:observation_index, letter: "A")
    assert_template(:list_names)
  end

  def test_authored_names
    get_with_dump(:authored_names)
    assert_template(:list_names)
  end

  def test_show_name
    assert_equal(0, QueryRecord.count)
    get_with_dump(:show_name, id: names(:coprinus_comatus).id)
    assert_template(:show_name, partial: "_name")
    # Creates three for children and all four observations sections,
    # but one never used.
    assert_equal(3, QueryRecord.count)

    get(:show_name, id: names(:coprinus_comatus).id)
    assert_template(:show_name, partial: "_name")
    # Should re-use all the old queries.
    assert_equal(3, QueryRecord.count)

    get(:show_name, id: names(:agaricus_campestris).id)
    assert_template(:show_name, partial: "_name")
    # Needs new queries this time.
    assert_equal(7, QueryRecord.count)

    # Agarcius: has children taxa.
    get(:show_name, id: names(:agaricus).id)
    assert_template(:show_name, partial: "_name")
  end

  def test_show_name_with_eol_link
    get(:show_name, id: names(:abortiporus_biennis_for_eol).id)
    assert_template(:show_name, partial: "_name")
  end

  def test_name_external_links_exist
    get(:show_name, id: names(:coprinus_comatus).id)

    assert_select("a[href *= 'images.google.com']")
    assert_select("a[href *= 'mycoportal.org']")
    assert_select("a[href *= 'mycobank.org']")
  end

  def test_mycobank_url
    get(:show_name, id: names(:coprinus_comatus).id)

    # There is a MycoBank link which includes taxon name and MycoBank language
    assert_select("a[href *= 'mycobank.org']") do
      assert_select("a[href *= '/Coprinus%20comatus']")
      assert_select("a[href *= 'Lang=Eng']")
    end
  end

  def test_show_name_locked
    name = Name.where(locked: true).first
    get_with_dump(:show_name, id: name.id)
    assert_select("a[href*=approve_name]", count: 0)
    assert_select("a[href*=deprecate_name]", count: 0)
    assert_select("a[href*=change_synonyms]", count: 0)
    login("rolf")
    get_with_dump(:show_name, id: name.id)
    assert_select("a[href*=approve_name]", count: 0)
    assert_select("a[href*=deprecate_name]", count: 0)
    assert_select("a[href*=change_synonyms]", count: 0)
    make_admin("mary")
    get_with_dump(:show_name, id: name.id)
    assert_select("a[href*=approve_name]", count: 0)
    assert_select("a[href*=deprecate_name]", count: 1)
    assert_select("a[href*=change_synonyms]", count: 1)

    Name.update(name.id, deprecated: true)
    logout
    get_with_dump(:show_name, id: name.id)
    assert_select("a[href*=approve_name]", count: 0)
    assert_select("a[href*=deprecate_name]", count: 0)
    assert_select("a[href*=change_synonyms]", count: 0)
    login("rolf")
    get_with_dump(:show_name, id: name.id)
    assert_select("a[href*=approve_name]", count: 0)
    assert_select("a[href*=deprecate_name]", count: 0)
    assert_select("a[href*=change_synonyms]", count: 0)
    make_admin("mary")
    get_with_dump(:show_name, id: name.id)
    assert_select("a[href*=approve_name]", count: 1)
    assert_select("a[href*=deprecate_name]", count: 0)
    assert_select("a[href*=change_synonyms]", count: 1)
  end

  def test_show_past_name
    get_with_dump(:show_past_name, id: names(:coprinus_comatus).id)
    assert_template(:show_past_name, partial: "_name")
  end

  def test_show_past_name_with_misspelling
    get_with_dump(:show_past_name, id: names(:petigera).id)
    assert_template(:show_past_name, partial: "_name")
  end

  def test_next_description
    description = name_descriptions(:coprinus_comatus_desc)
    id = description.id
    object = NameDescription.find(id)
    params = @controller.find_query_and_next_object(object, :next, id)
    get(:next_name_description, id: description.id)
    q = @controller.query_params(QueryRecord.last)
    assert_redirected_to(action: :show_name_description,
                         id: params[:id],
                         params: q)
  end

  def test_prev_description
    description = name_descriptions(:coprinus_comatus_desc)
    id = description.id
    object = NameDescription.find(id)
    params = @controller.find_query_and_next_object(object, :prev, id)
    get(:prev_name_description, id: description.id)
    q = @controller.query_params(QueryRecord.last)
    assert_redirected_to(action: :show_name_description,
                         id: params[:id],
                         params: q)
  end

  def test_next_and_prev
    names = Name.all.order("text_name, author").to_a
    name12 = names[12]
    name13 = names[13]
    name14 = names[14]
    get(:next_name, id: name12.id)
    q = @controller.query_params(QueryRecord.last)
    assert_redirected_to(action: :show_name, id: name13.id, params: q)
    get(:next_name, id: name13.id)
    assert_redirected_to(action: :show_name, id: name14.id, params: q)
    get(:prev_name, id: name14.id)
    assert_redirected_to(action: :show_name, id: name13.id, params: q)
    get(:prev_name, id: name13.id)
    assert_redirected_to(action: :show_name, id: name12.id, params: q)
  end

  def test_next_and_prev_2
    query = Query.lookup_and_save(:Name, :pattern_search, pattern: "lactarius")
    q = @controller.query_params(query)

    name1 = query.results[0]
    name2 = query.results[1]
    name3 = query.results[-2]
    name4 = query.results[-1]

    get(:next_name, q.merge(id: name1.id))
    assert_redirected_to(name2.show_link_args.merge(q))
    get(:next_name, q.merge(id: name3.id))
    assert_redirected_to(name4.show_link_args.merge(q))
    get(:next_name, q.merge(id: name4.id))
    assert_redirected_to(name4.show_link_args.merge(q))
    assert_flash_text(/no more/i)

    get(:prev_name, q.merge(id: name4.id))
    assert_redirected_to(name3.show_link_args.merge(q))
    get(:prev_name, q.merge(id: name2.id))
    assert_redirected_to(name1.show_link_args.merge(q))
    get(:prev_name, q.merge(id: name1.id))
    assert_redirected_to(name1.show_link_args.merge(q))
    assert_flash_text(/no more/i)
  end

  def test_names_by_user
    get_with_dump(:names_by_user, id: rolf.id)
    assert_template(:list_names)
  end

  def test_names_by_editor
    get_with_dump(:names_by_editor, id: rolf.id)
    assert_template(:list_names)
  end

  def test_needed_descriptions
    get_with_dump(:needed_descriptions)
    assert_template(:list_names)
  end

  def test_name_descriptions_by_author
    get_with_dump(:name_descriptions_by_author, id: rolf.id)
    assert_template(:list_name_descriptions)
  end

  def test_name_descriptions_by_editor
    get_with_dump(:name_descriptions_by_editor, id: rolf.id)
    assert_redirected_to(action: :show_name_description,
                         id: name_descriptions(:coprinus_comatus_desc).id,
                         params: @controller.query_params)
  end

  def test_name_search
    id = names(:agaricus).id
    get_with_dump(:name_search, pattern: id)
    assert_redirected_to(action: :show_name, id: id)
  end

  def test_name_search_help
    get_with_dump(:name_search, pattern: "help:me")
    assert_match(/unexpected term/i, @response.body)
  end

  def test_name_search_with_spelling_correction
    get_with_dump(:name_search, pattern: "agaricis campestrus")
    assert_template(:list_names)
    assert_select("div.alert-warning", 1)
    assert_select("a[href*='show_name/#{names(:agaricus_campestrus).id}']",
                  text: names(:agaricus_campestrus).search_name)
    assert_select("a[href*='show_name/#{names(:agaricus_campestras).id}']",
                  text: names(:agaricus_campestras).search_name)
    assert_select("a[href*='show_name/#{names(:agaricus_campestros).id}']",
                  text: names(:agaricus_campestros).search_name)

    get(:name_search, pattern: "Agaricus")
    assert_template(:list_names)
    assert_select("div.alert-warning", 0)
  end

  def test_advanced_search
    query = Query.lookup_and_save(:Name, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")
    get(:advanced_search, @controller.query_params(query))
    assert_template(:list_names)
  end

  def test_advanced_search_with_deleted_query
    query = Query.lookup_and_save(:Name, :advanced_search,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  location: "Eastern Oklahoma")
    params = @controller.query_params(query)
    query.record.delete
    get(:advanced_search, params)
    assert_redirected_to(controller: "observer",
                         action: "advanced_search_form")
  end

  def test_edit_name_get
    name = names(:coprinus_comatus)
    params = { "id" => name.id.to_s }
    requires_login(:edit_name, params)
    assert_form_action(action: "edit_name", id: name.id.to_s)
    assert_select("form #name_icn_identifier", { count: 1 },
                  "Form is missing field for icn_identifier")
  end

  def test_create_name_get
    requires_login(:create_name)
    assert_form_action(action: "create_name")
  end

  def test_show_name_description
    desc = name_descriptions(:peltigera_desc)
    params = { "id" => desc.id.to_s }
    get_with_dump(:show_name_description, params)
    assert_template(:show_name_description, partial: "_show_description")
  end

  def test_show_past_name_description
    login("dick")
    desc = name_descriptions(:peltigera_desc)
    old_versions = desc.versions.length
    desc.update(gen_desc: "something new which refers to _P. aphthosa_")
    desc.reload
    new_versions = desc.versions.length
    assert(new_versions > old_versions)
    get_with_dump(:show_past_name_description, id: desc.id)
    assert_template(:show_past_name_description, partial: "_name_description")
  end

  def test_create_name_description
    name = names(:peltigera)
    params = { "id" => name.id.to_s }
    requires_login(:create_name_description, params)
    assert_form_action(action: "create_name_description", id: name.id)
  end

  def test_edit_name_description
    desc = name_descriptions(:peltigera_desc)
    params = { "id" => desc.id.to_s }
    requires_login(:edit_name_description, params)
    assert_form_action(action: "edit_name_description", id: desc.id)
  end

  def test_bulk_name_edit_list
    requires_login(:bulk_name_edit)
    assert_form_action(action: "bulk_name_edit")
  end

  def test_change_synonyms
    name = names(:chlorophyllum_rachodes)
    params = { id: name.id }
    requires_login(:change_synonyms, params)
    assert_form_action(action: "change_synonyms",
                       approved_synonyms: [], id: name.id)
  end

  def test_deprecate_name
    name = names(:chlorophyllum_rachodes)
    params = { id: name.id }
    requires_login(:deprecate_name, params)
    assert_form_action(action: "deprecate_name", approved_name: "", id: name.id)
  end

  def test_approve_name
    name = names(:lactarius_alpigenes)
    params = { id: name.id }
    requires_login(:approve_name, params)
    assert_form_action(action: "approve_name", id: name.id)
  end

  def test_eol_expanded_review
    requires_login(:eol_expanded_review)
  end

  def test_eol
    get("eol")
  end

  def test_eol_preview
    get_with_dump("eol_preview")
  end

  def ids_from_links(links)
    links.map do |l|
      l.to_s.match(%r{.*\/([0-9]+)})[1].to_i
    end
  end

  def pagination_query_params
    query = Query.lookup_and_save(:Name, :all, by: :name)
    @controller.query_params(query)
  end

  # None of our standard tests ever actually renders pagination_links
  # or pagination_letters.  This tests all the above.
  def test_pagination_page1
    # Straightforward index of all names, showing first 10.
    query_params = pagination_query_params
    get(:test_index, { num_per_page: 10 }.merge(query_params))
    # print @response.body
    assert_template(:list_names)
    name_links = css_select(".table a")
    assert_equal(10, name_links.length)
    expected = Name.all.order("text_name, author").limit(10).to_a
    assert_equal(expected.map(&:id), ids_from_links(name_links))
    # assert_equal(@controller.url_with_query(action: "show_name",
    #  id: expected.first.id, only_path: true), name_links.first.url)
    url = @controller.url_with_query(action: "show_name",
                                     id: expected.first.id, only_path: true)
    assert_not_nil(name_links.first.to_s.index(url))
    assert_select("a", text: "1", count: 0)
    assert_link_in_html("2", action: :test_index, num_per_page: 10,
                             params: query_params, page: 2)
    assert_select("a", text: "Z", count: 0)
    assert_link_in_html("A", action: :test_index, num_per_page: 10,
                             params: query_params, letter: "A")
  end

  def test_pagination_page2
    # Now go to the second page.
    query_params = pagination_query_params
    get(:test_index, { num_per_page: 10, page: 2 }.merge(query_params))
    assert_template(:list_names)
    name_links = css_select(".table a")
    assert_equal(10, name_links.length)
    expected = Name.all.order("sort_name").limit(10).offset(10).to_a
    assert_equal(expected.map(&:id), ids_from_links(name_links))
    url = @controller.url_with_query(action: "show_name",
                                     id: expected.first.id, only_path: true)
    assert_not_nil(name_links.first.to_s.index(url))

    assert_select("a", text: "2", count: 0)
    assert_link_in_html("1", action: :test_index, num_per_page: 10,
                             params: query_params, page: 1)
    assert_select("a", text: "Z", count: 0)
    assert_link_in_html("A", action: :test_index, num_per_page: 10,
                             params: query_params, letter: "A")
  end

  def test_pagination_letter
    # Now try a letter.
    query_params = pagination_query_params
    #    l_names = Name.all(conditions: 'text_name LIKE "L%"', # Rails 3
    #      order: 'text_name, author')
    l_names = Name.where("text_name LIKE 'L%'").order("text_name, author").to_a
    get(:test_index, { num_per_page: l_names.size,
                       letter: "L" }.merge(query_params))
    assert_template(:list_names)
    assert_select("div#content")
    name_links = css_select(".table a")
    assert_equal(l_names.size, name_links.length)
    # (Mysql and ruby sort "Kuhner" and "Kühner" oppositely. Just ignore them.)
    assert_equal(l_names.map(&:id) - [35, 36],
                 ids_from_links(name_links) - [35, 36])

    url = @controller.url_with_query(action: "show_name",
                                     id: l_names.first.id, only_path: true)
    assert_not_nil(name_links.first.to_s.index(url))
    assert_select("a", text: "1", count: 0)
    assert_select("a", text: "Z", count: 0)

    assert_link_in_html("A", action: :test_index, params: query_params,
                             num_per_page: l_names.size, letter: "A")
  end

  def test_pagination_letter_with_page
    query_params = pagination_query_params
    #    l_names = Name.all(conditions: 'text_name LIKE "L%"', # Rails 3
    #      order: 'text_name, author')
    l_names = Name.where("text_name LIKE 'L%'").order("text_name, author").to_a
    # Do it again, but make page size exactly one too small.
    l_names.pop
    get(:test_index, { num_per_page: l_names.size,
                       letter: "L" }.merge(query_params))
    assert_template(:list_names)
    name_links = css_select(".table a")

    assert_equal(l_names.size, name_links.length)
    assert_equal(l_names.map(&:id) - [35, 36],
                 ids_from_links(name_links) - [35, 36])

    assert_select("a", text: "1", count: 0)

    assert_link_in_html("2", action: :test_index, params: query_params,
                             num_per_page: l_names.size,
                             letter: "L", page: 2)

    assert_select("a", text: "3", count: 0)
  end

  def test_pagination_letter_with_page_2
    query_params = pagination_query_params
    l_names = Name.where("text_name LIKE 'L%'").order("text_name, author").to_a
    last_name = l_names.pop
    # Check second page.
    get(:test_index, { num_per_page: l_names.size, letter: "L",
                       page: 2 }.merge(query_params))
    assert_template(:list_names)
    name_links = css_select(".table a")
    assert_equal(1, name_links.length)
    assert_equal([last_name.id], ids_from_links(name_links))
    assert_select("a", text: "2", count: 0)
    assert_link_in_html("1", action: :test_index, params: query_params,
                             num_per_page: l_names.size,
                             letter: "L", page: 1)
    assert_select("a", text: "3", count: 0)
  end

  def test_pagination_with_anchors
    query_params = pagination_query_params
    # Some cleverness is required to get pagination links to include anchors.
    get(:test_index, {
      num_per_page: 10,
      test_anchor: "blah"
    }.merge(query_params))
    assert_link_in_html("2", action: :test_index, num_per_page: 10,
                             params: query_params, page: 2,
                             test_anchor: "blah", anchor: "blah")
    assert_link_in_html("A", action: :test_index, num_per_page: 10,
                             params: query_params, letter: "A",
                             test_anchor: "blah", anchor: "blah")
  end

  def test_name_guessing
    # Not all the genera actually have records in our test database.
    User.current = rolf
    @controller.instance_variable_set("@user", rolf)
    Name.create_needed_names("Agaricus")
    Name.create_needed_names("Pluteus")
    Name.create_needed_names("Coprinus comatus subsp. bogus var. varietus")

    assert_name_suggestions("Agricus")
    assert_name_suggestions("Ptligera")
    assert_name_suggestions(" plutues _petastus  ")
    assert_name_suggestions("Coprinis comatis")
    assert_name_suggestions("Coprinis comatis blah. boggle")
    assert_name_suggestions("Coprinis comatis blah. boggle var. varitus")
  end

  def assert_name_suggestions(str)
    results = Name.suggest_alternate_spellings(str)
    assert(results.any?,
           "Couldn't suggest alternate spellings for #{str.inspect}.")
  end

  # ----------------------------
  #  Maps
  # ----------------------------

  # name with Observations that have Locations
  def test_map
    get_with_dump(:map, id: names(:agaricus_campestris).id)
    assert_template(:map)
  end

  # name with Observations that don't have Locations
  def test_map_no_loc
    get_with_dump(:map, id: names(:coprinus_comatus).id)
    assert_template(:map)
  end

  # name with no Observations
  def test_map_no_obs
    get_with_dump(:map, id: names(:conocybe_filaris).id)
    assert_template(:map)
  end

  # ----------------------------
  #  Create name.
  # ----------------------------

  def test_create_name_post
    text_name = "Amanita velosa"
    author = "Lloyd"
    name = Name.find_by(text_name: text_name)
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        author: author,
        rank: :Species,
        citation: "__Mycol. Writ.__ 9(15). 1898."
      }
    }
    post_requires_login(:create_name, params)

    assert(name = Name.find_by(text_name: text_name))
    assert_redirected_to(action: :show_name, id: name.id)
    assert_equal(10 + @new_pts, rolf.reload.contribution)
    assert_equal(author, name.author)
    assert_equal(rolf, name.user)
  end

  def test_create_name_existing
    name = names(:conocybe_filaris)
    text_name = name.text_name
    count = Name.count
    params = {
      name: {
        text_name: text_name,
        author: "",
        rank: :Species,
        citation: ""
      }
    }
    login("rolf")
    post(:create_name, params)

    assert_response(:success)
    assert_equal(count, Name.count,
                 "Shouldn't have created #{Name.last.search_name.inspect}.")
    names = Name.where(text_name: text_name)
    assert_obj_list_equal([names(:conocybe_filaris)], names)
    assert_equal(10, rolf.reload.contribution)
  end

  def test_create_name_matching_multiple_names
    desired_name = names(:coprinellus_micaceus_no_author)
    text_name = desired_name.text_name
    params = {
      name: {
        text_name: text_name,
        author: "",
        rank: desired_name.rank,
        citation: desired_name.citation
      }
    }
    flash_text = :create_name_multiple_names_match.t(str: text_name)
    count = Name.count
    login("rolf")
    post(:create_name, params)

    assert_flash_text(flash_text)
    assert_response(:success)
    assert_equal(count, Name.count,
                 "Shouldn't have created #{Name.last.search_name.inspect}.")
  end

  def test_create_name_unauthored_authored
    # Prove user can't create authored non-:Group Name if unauthored one exists.
    old_name_count = Name.count
    name = names(:strobilurus_diminutivus_no_author)
    params = {
      name: {
        text_name: name.text_name,
        author: "Author",
        rank: name.rank,
        status: name.status
      }
    }
    user = users(:rolf)
    login(user.login)
    post(:create_name, params)

    assert_response(:success)
    flash_text = :runtime_name_create_already_exists.t(name: name.display_name)
    assert_flash_text(flash_text)
    assert_empty(name.reload.author)
    assert_equal(old_name_count, Name.count)
    expect = user.contribution
    assert_equal(expect, user.reload.contribution)

    # And vice versa
    # Prove user can't create unauthored non-:Group Name if authored one exists.
    name = names(:coprinus_comatus)
    author = name.author
    params = {
      name: {
        text_name: name.text_name,
        author: "",
        rank: name.rank,
        status: name.status
      }
    }
    post(:create_name, params)

    assert_response(:success)
    flash_text = :runtime_name_create_already_exists.t(name: name.display_name)
    assert_flash_text(flash_text)
    assert_equal(author, name.reload.author)
    assert_equal(old_name_count, Name.count)
    expect = user.contribution
    assert_equal(expect, user.reload.contribution)
  end

  def test_create_name_authored_group_unauthored_exists
    name = names(:unauthored_group)
    text_name = name.text_name
    params = {
      name: {
        text_name: text_name,
        author: "Author",
        rank: :Group,
        citation: ""
      }
    }
    login("rolf")
    old_contribution = rolf.contribution
    post(:create_name, params)

    assert(authored_name = Name.find_by(search_name: "#{text_name} Author"))
    assert_flash_success
    assert_redirected_to(action: :show_name, id: authored_name.id)
    assert(Name.exists?(name.id))
    assert_equal(old_contribution + SiteData::FIELD_WEIGHTS[:names],
                 rolf.reload.contribution)
  end

  def test_create_name_bad_name
    text_name = "Amanita Pantherina"
    name = Name.find_by(text_name: text_name)
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        rank: :Species
      }
    }
    login("rolf")
    post(:create_name, params)
    assert_template(:create_name, partial: "_form_name")
    # Should fail and no name should get created
    assert_nil(Name.find_by(text_name: text_name))
    assert_form_action(action: "create_name")
  end

  def test_create_name_author_limit
    # Prove author :limit is number of characters, not bytes
    text_name = "Max-size-author"
    # String with author_limit multi-byte characters, and > author_limit bytes
    author    = "Á#{"æ" * (Name.author_limit - 1)}"
    params = {
      name: {
        text_name: text_name,
        author: author,
        rank: :Genus
      }
    }
    post_requires_login(:create_name, params)

    assert(name = Name.find_by(text_name: text_name), "Failed to create name")
    assert_equal(author, name.author)
  end

  def test_create_name_alt_rank
    text_name = "Ustilaginomycetes"
    name = Name.find_by(text_name: text_name)
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        rank: :Phylum
      }
    }
    login("rolf")
    post(:create_name, params)
    assert_redirected_to(action: :show_name,
                         id: Name.find_by(text_name: text_name).id)
    assert(Name.find_by(text_name: text_name))
  end

  def test_create_name_with_many_implicit_creates
    text_name = "Genus spec ssp. subspecies v. variety forma form"
    text_name2 = "Genus spec subsp. subspecies var. variety f. form"
    name = Name.find_by(text_name: text_name)
    count = Name.count
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        rank: :Form
      }
    }
    login("rolf")
    post(:create_name, params)
    assert_redirected_to(action: :show_name,
                         id: Name.find_by(text_name: text_name2).id)
    assert(name = Name.find_by(text_name: text_name2))
    assert_equal(count + 5, Name.count)
  end

  def test_create_species_under_ambiguous_genus
    login("dick")
    agaricus1 = names(:agaricus)
    agaricus1.change_author("L.")
    agaricus1.save
    Name.create!(
      text_name: "Agaricus",
      search_name: "Agaricus Raf.",
      sort_name: "Agaricus Raf.",
      display_name: "**__Agaricus__** Raf.",
      author: "Raf.",
      rank: :Genus,
      deprecated: false,
      correct_spelling: nil
    )
    agarici = Name.where(text_name: "Agaricus")
    assert_equal(2, agarici.length)
    assert_equal("L.", agarici.first.author)
    assert_equal("Raf.", agarici.last.author)
    params = {
      name: {
        text_name: "Agaricus endoxanthus",
        author: "",
        rank: :Species,
        citation: "",
        deprecated: "false"
      }
    }
    post(:create_name, params)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: Name.last.id)
  end

  def test_create_family
    login("dick")
    params = {
      name: {
        text_name: "Lecideaceae",
        author: "",
        rank: :Genus,
        citation: "",
        deprecated: "false"
      }
    }
    post(:create_name, params)
    assert_flash_error
    params[:name][:rank] = :Family
    post(:create_name, params)
    assert_flash_success
  end

  def test_create_variety
    text_name = "Pleurotus djamor var. djamor"
    author    = "(Fr.) Boedijn"
    params = {
      name: {
        text_name: "#{text_name} #{author}",
        author: "",
        rank: :Variety,
        deprecated: "false"
      }
    }
    login("katrina")
    post(:create_name, params)

    assert(name = Name.find_by(text_name: text_name))
    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_no_emails
    assert_equal(:Variety, name.rank)
    assert_equal("#{text_name} #{author}", name.search_name)
    assert_equal(author, name.author)
    assert(Name.find_by(text_name: "Pleurotus djamor"))
    assert(Name.find_by(text_name: "Pleurotus"))
  end

  # ----------------------------
  #  Edit name -- without merge
  # ----------------------------

  def test_edit_name_post
    name = names(:conocybe_filaris)
    assert_equal("Conocybe filaris", name.text_name)
    assert_blank(name.author)
    assert_equal(1, name.version)
    params = {
      id: name.id,
      name: {
        text_name: "Conocybe filaris",
        author: "(Fr.) Kühner",
        rank: :Species,
        citation: "__Le Genera Galera__, 139. 1935.",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    post_requires_login(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_equal(10, rolf.reload.contribution)
    assert_equal("(Fr.) Kühner", name.reload.author)
    assert_equal("**__Conocybe filaris__** (Fr.) Kühner", name.display_name)
    assert_equal("Conocybe filaris (Fr.) Kühner", name.search_name)
    assert_equal("__Le Genera Galera__, 139. 1935.", name.citation)
    assert_equal(rolf, name.user)
  end

  def test_edit_name_no_changes
    name = names(:conocybe_filaris)
    text_name  = name.text_name
    author     = name.author
    rank       = name.rank
    citation   = name.citation
    deprecated = name.deprecated
    params = {
      id: name.id,
      name: {
        text_name: text_name,
        author: author,
        rank: rank,
        citation: citation,
        deprecated: (deprecated ? "true" : "false")
      }
    }
    user = name.user
    contribution = user.contribution
    login(user.login)
    post(:edit_name, params)

    assert_flash_text(:runtime_no_changes.l)
    assert_redirected_to(action: :show_name, id: name.id)
    assert_equal(text_name, name.reload.text_name)
    assert_equal(author, name.author)
    assert_equal(rank, name.rank)
    assert_equal(citation, name.citation)
    assert_equal(deprecated, name.deprecated)
    assert_equal(user, name.user)
    assert_equal(contribution, user.contribution)
  end

  # This catches a bug that was happening when editing a name that was in use.
  # In this case text_name and author are missing, confusing edit_name.
  def test_edit_name_post_name_and_author_missing
    names(:conocybe).destroy
    name = names(:conocybe_filaris)
    params = {
      id: name.id,
      name: {
        rank: :Species,
        citation: "__Le Genera Galera__, 139. 1935.",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_no_emails
    assert_equal("", name.reload.author)
    assert_equal("__Le Genera Galera__, 139. 1935.", name.citation)
    assert_equal(rolf, name.user)
    assert_equal(10, rolf.reload.contribution)
  end

  def test_edit_name_unchangeable_plus_admin_email
    name = names(:other_user_owns_naming_name)
    user = name.user
    contribution = user.contribution
    # Change the first word
    desired_text_name = name.text_name.
                        sub(/\S+/, "Big-change-to-force-email-to-admin")
    params = {
      id: name.id,
      name: {
        text_name: desired_text_name,
        author: "",
        rank: name.rank,
        deprecated: "false"
      }
    }
    login(name.user.login)
    post(:edit_name, params)

    assert(@@emails.one?)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_equal(desired_text_name, name.reload.search_name)
    assert_equal(contribution, user.reload.contribution)
  end

  def test_edit_name_post_just_change_notes
    # has blank notes
    name = names(:conocybe_filaris)
    past_names = name.versions.size
    new_notes = "Add this to the notes."
    params = {
      id: name.id,
      name: {
        text_name: "Conocybe filaris",
        author: "",
        rank: :Species,
        citation: "",
        notes: new_notes,
        deprecated: (name.deprecated ? "true" : "false")

      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_no_emails
    assert_equal(@new_pts, rolf.reload.contribution)
    assert_equal(new_notes, name.reload.notes)
    assert_equal(past_names + 1, name.versions.size)
  end

  def test_edit_deprecated_name_remove_author
    name = names(:lactarius_alpigenes)
    assert(name.deprecated)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: "",
        rank: :Species,
        citation: "new citation",
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login("mary")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_email_generated
    assert(Name.exists?(text_name: "Lactarius"))
    # points for changing Lactarius alpigenes
    assert_equal(@new_pts + @chg_pts, mary.reload.contribution)
    assert(name.reload.deprecated)
    assert_equal("new citation", name.citation)
  end

  def test_edit_name_add_author
    name = names(:strobilurus_diminutivus_no_author)
    old_text_name = name.text_name
    new_author = "Desjardin"
    params = {
      id: name.id,
      name: {
        text_name: old_text_name,
        author: new_author,
        rank: :Species,
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login("mary")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_equal(@new_pts + @chg_pts, mary.reload.contribution)
    assert_equal(new_author, name.reload.author)
    assert_equal(old_text_name, name.text_name)
  end

  # Prove that user can change name -- without merger --
  # if there's no exact match to desired Name
  def test_edit_name_remove_author_no_exact_match
    name = names(:amanita_baccata_arora)
    params = {
      id: name.id,
      name: {
        text_name: names(:coprinus_comatus).text_name,
        author: "",
        rank: names(:coprinus_comatus).rank,
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login(name.user.login)
    post(:edit_name, params)

    assert_redirected_to(action: :show_name, id: name.id)
    assert_flash_success
    assert_empty(name.reload.author)
    assert_email_generated
  end

  def test_edit_name_misspelling
    login("rolf")

    # Prove we can clear misspelling by unchecking "misspelt" box
    name = names(:petigera)
    assert_true(name.reload.is_misspelling?)
    assert_names_equal(names(:peltigera), name.correct_spelling)
    assert_true(name.deprecated)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: "true",
        misspelling: ""
      }
    }
    post(:edit_name, params)
    assert_flash_success
    assert_false(name.reload.is_misspelling?)
    assert_nil(name.correct_spelling)
    assert_true(name.deprecated)
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)

    # Prove we can deprecate and call a name misspelt by checking box and
    # entering correct spelling.
    Name.update(name.id, deprecated: false)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: "false",
        misspelling: "1",
        correct_spelling: "Peltigera"
      }
    }
    post(:edit_name, params)
    assert_flash_success
    assert_true(name.reload.is_misspelling?)
    assert_equal("__Petigera__", name.display_name)
    assert_names_equal(names(:peltigera), name.correct_spelling)
    assert_true(name.deprecated)
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)

    # Prove we cannot correct misspelling with unrecognized Name
    name = names(:suilus)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: (name.deprecated ? "true" : "false"),
        misspelling: 1,
        correct_spelling: "Qwertyuiop"
      }
    }
    post(:edit_name, params)
    assert_flash_error
    assert(name.reload.is_misspelling?)

    # Prove we cannot correct misspelling with same Name
    name = names(:suilus)
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: name.rank,
        deprecated: (name.deprecated ? "true" : "false"),
        misspelling: 1,
        correct_spelling: name.text_name
      }
    }
    post(:edit_name, params)
    assert_flash_error
    assert(name.reload.is_misspelling?)

    # Prove we can swap misspelling and correct_spelling
    # Change "Suillus E.B. White" to "Suilus E.B. White"
    old_misspelling = names(:suilus)
    old_correct_spelling = old_misspelling.correct_spelling
    params = {
      id: old_correct_spelling.id,
      name: {
        text_name: old_correct_spelling.text_name,
        author: old_correct_spelling.author,
        rank: old_correct_spelling.rank,
        deprecated: (old_correct_spelling.deprecated ? "true" : "false"),
        misspelling: 1,
        correct_spelling: old_misspelling.text_name
      }
    }
    post(:edit_name, params)
    # old_correct_spelling's spelling status and deprecation should change
    assert(old_correct_spelling.reload.is_misspelling?)
    assert_equal(old_misspelling, old_correct_spelling.correct_spelling)
    assert(old_correct_spelling.deprecated)
    # old_misspelling's spelling status should change but deprecation should not
    assert_not(old_misspelling.reload.is_misspelling?)
    assert_empty(old_misspelling.correct_spelling)
    assert(old_misspelling.deprecated)
  end

  def test_edit_name_by_user_who_doesnt_own_name
    name = names(:macrolepiota_rhacodes)
    name_owner = name.user
    params = {
      id: name.id,
      name: {
        text_name: name.text_name,
        author: name.author,
        rank: :Species,
        citation: name.citation,
        deprecated: (name.deprecated ? "true" : "false")
      }
    }
    login(rolf.login)
    post(:edit_name, params)

    assert_flash_warning
    assert_redirected_to(action: :show_name, id: name.id)
    assert_no_emails
    assert_equal(@new_pts, rolf.reload.contribution)
    # (But owner remains of course.)
    assert_equal(name_owner, name.reload.user)
  end

  def test_edit_name_chain_to_approve_and_deprecate
    login("rolf")
    name = names(:lactarius_alpigenes)
    params = {
      id: name.id,
      name: {
        rank: name.rank,
        text_name: name.text_name,
        author: name.author,
        citation: name.citation,
        notes: name.notes
      }
    }

    # No change: go to show_name, warning.
    params[:name][:deprecated] = "true"
    post(:edit_name, params)
    assert_flash_warning
    assert_redirected_to(action: :show_name, id: name.id)
    assert_no_emails

    # Change to accepted: go to approve_name, no flash.
    params[:name][:deprecated] = "false"
    post(:edit_name, params)
    assert_no_flash
    assert_redirected_to(action: :approve_name, id: name.id)

    # Change to deprecated: go to deprecate_name, no flash.
    name.change_deprecated(false)
    name.save
    params[:name][:deprecated] = "true"
    post(:edit_name, params)
    assert_no_flash
    assert_redirected_to(action: :deprecate_name, id: name.id)
  end

  def test_edit_name_with_umlaut
    login("dick")
    names = Name.find_or_create_name_and_parents("Xanthoparmelia coloradoensis")
    names.each(&:save)
    name = names.last
    assert_equal("Xanthoparmelia coloradoensis", name.text_name)
    assert_equal("Xanthoparmelia coloradoensis", name.search_name)
    assert_equal("**__Xanthoparmelia coloradoensis__**", name.display_name)

    get(:edit_name, id: name.id)
    assert_input_value("name_text_name", "Xanthoparmelia coloradoensis")
    assert_input_value("name_author", "")

    params = {
      id: name.id,
      name: {
        # (test what happens if user puts author in wrong field)
        text_name: "Xanthoparmelia coloradoënsis (Gyelnik) Hale",
        author: "",
        rank: :Species,
        deprecated: "false"
      }
    }
    post(:edit_name, params)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_no_emails
    name.reload
    assert_equal("Xanthoparmelia coloradoensis", name.text_name)
    assert_equal("Xanthoparmelia coloradoensis (Gyelnik) Hale",
                 name.search_name)
    assert_equal("**__Xanthoparmelia coloradoënsis__** (Gyelnik) Hale",
                 name.display_name)

    get(:edit_name, id: name.id)
    assert_input_value("name_text_name", "Xanthoparmelia coloradoënsis")
    assert_input_value("name_author", "(Gyelnik) Hale")

    params[:name][:text_name] = "Xanthoparmelia coloradoensis"
    params[:name][:author] = ""
    post(:edit_name, params)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_email_generated
    name.reload
    assert_equal("Xanthoparmelia coloradoensis", name.text_name)
    assert_equal("Xanthoparmelia coloradoensis", name.search_name)
    assert_equal("**__Xanthoparmelia coloradoensis__**", name.display_name)
  end

  def test_edit_name_fixing_variety
    login("katrina")
    name = Name.create!(
      text_name: "Pleurotus djamor",
      search_name: "Pleurotus djamor (Fr.) Boedijn var. djamor",
      sort_name: "Pleurotus djamor (Fr.) Boedijn var. djamor",
      display_name: "**__Pleurotus djamor__** (Fr.) Boedijn var. djamor",
      author: "(Fr.) Boedijn var. djamor",
      rank: :Species,
      deprecated: false,
      correct_spelling: nil
    )
    params = {
      id: name.id,
      name: {
        text_name: "Pleurotus djamor var. djamor (Fr.) Boedijn",
        author: "",
        rank: :Variety,
        deprecated: "false"
      }
    }
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_no_emails
    name.reload
    assert_equal(:Variety, name.rank)
    assert_equal("Pleurotus djamor var. djamor", name.text_name)
    assert_equal("Pleurotus djamor var. djamor (Fr.) Boedijn", name.search_name)
    assert_equal("(Fr.) Boedijn", name.author)
    # In the bug in the wild, it was failing to create the parents.
    assert(Name.find_by(text_name: "Pleurotus djamor"))
    assert(Name.find_by(text_name: "Pleurotus"))
  end

  def test_edit_name_change_to_group
    login("mary")
    name = Name.create!(
      text_name: "Lepiota echinatae",
      search_name: "Lepiota echinatae Group",
      sort_name: "Lepiota echinatae Group",
      display_name: "**__Lepiota echinatae__** Group",
      author: "Group",
      rank: :Species,
      deprecated: false,
      correct_spelling: nil
    )
    params = {
      id: name.id,
      name: {
        text_name: "Lepiota echinatae",
        author: "Group",
        rank: :Group,
        deprecated: "false"
      }
    }
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: name.id)
    assert_no_emails
    name.reload
    assert_equal(:Group, name.rank)
    assert_equal("Lepiota echinatae group", name.text_name)
    assert_equal("Lepiota echinatae group", name.search_name)
    assert_equal("**__Lepiota echinatae__** group", name.display_name)
    assert_equal("", name.author)
  end

  def test_edit_name_screwy_notification_bug
    login("mary")
    name = Name.create!(
      text_name: "Ganoderma applanatum",
      search_name: "Ganoderma applanatum",
      sort_name: "Ganoderma applanatum",
      display_name: "__Ganoderma applanatum__",
      author: "",
      rank: :Species,
      deprecated: true,
      correct_spelling: nil,
      citation: "",
      notes: ""
    )
    Interest.create!(
      target: name,
      user: rolf,
      state: true
    )
    params = {
      id: name.id,
      name: {
        text_name: "Ganoderma applanatum",
        author: "",
        rank: :Species,
        deprecated: "true",
        citation: "",
        notes: "Changed notes."
      }
    }
    post(:edit_name, params)
    # was crashing while notifying rolf because new version wasn't saved yet
    assert_flash_success
  end

  # Prove that editing can create multiple ancestors
  def test_edit_name_create_multiple_ancestors
    name        = names(:two_ancestors)
    new_name    = "Neo#{name.text_name.downcase}"
    new_species = new_name.sub(/(\w* \w*).*/, '\1')
    new_genus   = new_name.sub(/(\w*).*/, '\1')
    name_count  = Name.count
    params = {
      id: name.id,
      name: {
        text_name: new_name,
        author: name.author,
        rank: name.rank
      }
    }
    login(name.user.login)
    post(:edit_name, params)

    assert_equal(name_count + 2, Name.count)
    assert(Name.exists?(text_name: new_species), "Failed to create new species")
    assert(Name.exists?(text_name: new_genus), "Failed to create new genus")
  end

  def test_post_edit_name_locked
    name = names(:fungi)
    params = {
      id: name.id,
      name: {
        locked: "0",
        rank: "Genus",
        deprecated: "true",
        text_name: "Foo",
        author: "Bar",
        citation: "new citation",
        notes: "new notes"
      }
    }

    login("rolf")
    get(:edit_name, id: name.id)
    assert_select("select#name_rank", count: 0)
    assert_select("select#name_deprecated", count: 0)
    assert_select("input[type=text]#name_text_name", count: 0)
    assert_select("input[type=text]#name_author", count: 0)
    assert_select("input[type=checkbox]#name_misspelling", count: 0)
    assert_select("input[type=text]#name_correct_spelling", count: 0)

    post(:edit_name, params)
    name.reload
    assert_true(name.locked)
    assert_equal(:Kingdom, name.rank)
    assert_false(name.deprecated)
    assert_equal("Fungi", name.text_name)
    assert_equal("", name.author)
    assert_nil(name.correct_spelling_id)
    assert_equal("new citation", name.citation)
    assert_equal("new notes", name.notes)

    make_admin("mary")
    get(:edit_name, id: name.id)
    assert_select("select#name_rank", count: 1)
    assert_select("select#name_deprecated", count: 1)
    assert_select("input[type=text]#name_text_name", count: 1)
    assert_select("input[type=text]#name_author", count: 1)
    assert_select("input[type=checkbox]#name_misspelling", count: 1)
    assert_select("input[type=text]#name_correct_spelling", count: 1)

    post(:edit_name, params)
    name.reload
    assert_false(name.locked)
    assert_equal(:Genus, name.rank)
    assert_true(name.deprecated)
    assert_equal("Foo", name.text_name)
    assert_equal("Bar", name.author)
  end

  def test_edit_misspelled_name
    misspelled_name = names(:suilus)
    login("rolf")
    get(:edit_name, id: misspelled_name.id)
    assert_select("input[type=checkbox]#name_misspelling", count: 1)
    assert_select("input[type=text]#name_correct_spelling", count: 1)
  end

  # ----------------------------
  #  Edit name -- with merge
  # ----------------------------

  def test_edit_name_destructive_merge
    old_name = agaricus_campestrus = names(:agaricus_campestrus)
    new_name = agaricus_campestris = names(:agaricus_campestris)
    new_versions = new_name.versions.size
    old_obs = old_name.namings[0].observation
    new_obs = new_name.namings.
              select { |n| n.observation.name == new_name }[0].observation

    params = {
      id: old_name.id,
      name: {
        text_name: agaricus_campestris.text_name,
        author: agaricus_campestris.author,
        rank: :Species,
        deprecated: agaricus_campestris.deprecated
      }
    }
    login("rolf")

    # Fails because Rolf isn't in admin mode.
    post(:edit_name, params)
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Name, old_id: old_name.id, new_id: new_name.id)
    assert(Name.find(old_name.id))
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(2, new_name.namings.size)
    assert_equal(agaricus_campestrus, old_obs.reload.name)
    assert_equal(agaricus_campestris, new_obs.reload.name)

    # Try again as an admin.
    make_admin
    post(:edit_name, params)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(3, new_name.namings.size)
    assert_equal(agaricus_campestris, old_obs.reload.name)
    assert_equal(agaricus_campestris, new_obs.reload.name)
  end

  def test_edit_name_author_merge
    # Names differing only in author
    old_name = names(:amanita_baccata_borealis)
    new_name = names(:amanita_baccata_arora)
    new_author = new_name.author
    new_versions = new_name.versions.size
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: new_name.author,
        rank: :Species,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
    assert_equal(new_author, new_name.reload.author)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
  end

  # Prove that user can remove author if there's a match to desired Name,
  # and the merge is non-destructive
  def test_edit_name_remove_author_nondestructive_merge
    old_name   = names(:mergeable_epithet_authored)
    new_name   = names(:mergeable_epithet_unauthored)
    name_count = Name.count
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: "",
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(old_name.user.login)
    post(:edit_name, params)

    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_flash_success
    assert_empty(new_name.reload.author)
    assert_no_emails
    assert_equal(name_count - 1, Name.count)
    assert_not(Name.exists?(old_name.id))
  end

  # Prove that user can add author if there's a match to desired Name,
  # and the merge is non-destructive
  def test_edit_name_add_author_nondestructive_merge
    old_name   = names(:mergeable_epithet_unauthored)
    new_name   = names(:mergeable_epithet_authored)
    new_author = new_name.author
    name_count = Name.count
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: new_author,
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login(old_name.user.login)
    post(:edit_name, params)

    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_flash_success
    assert_equal(new_author, new_name.reload.author)
    assert_no_emails
    assert_equal(name_count - 1, Name.count)
    assert_not(Name.exists?(old_name.id))
  end

  def test_edit_name_remove_author_destructive_merge
    old_name = names(:authored_with_naming)
    new_name = names(:unauthored_with_naming)
    params = {
      id: old_name.id,
      name: {
        text_name: old_name.text_name,
        author: "",
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }

    login("rolf")
    post(:edit_name, params)
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Name, old_id: old_name.id, new_id: new_name.id)

    # Try again as an admin.
    make_admin
    post(:edit_name, params)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
  end

  def test_edit_name_merge_author_with_notes
    bad_name = names(:hygrocybe_russocoriacea_bad_author)
    bad_id = bad_name.id
    bad_notes = bad_name.notes
    good_name = names(:hygrocybe_russocoriacea_good_author)
    good_id = good_name.id
    good_author = good_name.author
    params = {
      id: bad_name.id,
      name: {
        text_name: bad_name.text_name,
        author: good_author,
        notes: bad_notes,
        rank: :Species,
        deprecated: (bad_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    make_admin
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: good_id)
    assert_no_emails
    assert_not(Name.exists?(bad_id))
    reload_name = Name.find(good_id)
    assert(reload_name)
    assert_equal(good_author, reload_name.author)
    assert_equal(bad_notes, reload_name.notes)
  end

  # Make sure misspelling gets transferred when new name merges away.
  def test_edit_name_misspelling_merge
    old_name = names(:suilus)
    wrong_author_name = names(:suillus_by_white)
    new_name = names(:suillus)
    old_correct_spelling_id = old_name.correct_spelling_id
    params = {
      id: wrong_author_name.id,
      name: {
        text_name: wrong_author_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        deprecated: (wrong_author_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_no_emails
    assert_not(Name.exists?(wrong_author_name.id))
    assert_not_equal(old_correct_spelling_id,
                     old_name.reload.correct_spelling_id)
    assert_equal(old_name.correct_spelling, new_name)
  end

  # Test that merged names end up as not deprecated if the
  # new name is not deprecated.
  def test_edit_name_deprecated_merge
    old_name = names(:lactarius_alpigenes)
    new_name = names(:lactarius_alpinus)
    new_author = new_name.author
    new_versions = new_name.versions.size
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: :Species,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_no_emails
    assert_not(Name.exists?(old_name.id))
    assert(new_name.reload)
    assert_not(new_name.deprecated)
    assert_equal(new_author, new_name.author)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
  end

  # Test that merged name doesn't change deprecated status
  # unless the user explicitly changes status in form.
  def test_edit_name_deprecated2_merge
    good_name = names(:lactarius_alpinus)
    bad_name1 = names(:lactarius_alpigenes)
    bad_name2 = names(:lactarius_kuehneri)
    bad_name3 = names(:lactarius_subalpinus)
    bad_name4 = names(:pluteus_petasatus_approved)
    good_text_name = good_name.text_name
    good_author = good_name.author

    # First: merge deprecated into accepted, no change.
    assert_not(good_name.deprecated)
    assert(bad_name1.deprecated)
    params = {
      id: bad_name1.id,
      name: {
        text_name: good_name.text_name,
        author: good_name.author,
        rank: :Species,
        deprecated: "false"
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: good_name.id)
    assert_no_emails
    assert_not(Name.exists?(bad_name1.id))
    assert(good_name.reload)
    assert_not(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(1, good_name.version)
    assert_equal(1, good_name.versions.size)

    # Second: merge accepted into deprecated, no change.
    good_name.change_deprecated(true)
    bad_name2.change_deprecated(false)
    good_name.save
    bad_name2.save
    assert_equal(2, good_name.version)
    assert_equal(2, good_name.versions.size)

    assert(good_name.deprecated)
    assert_not(bad_name2.deprecated)
    params[:id] = bad_name2.id
    params[:name][:deprecated] = "true"
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: good_name.id)
    assert_no_emails
    assert_not(Name.exists?(bad_name2.id))
    assert(good_name.reload)
    assert(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(2, good_name.version)
    assert_equal(2, good_name.versions.size)

    # Third: merge deprecated into deprecated, but change to accepted.
    assert(good_name.deprecated)
    assert(bad_name3.deprecated)
    params[:id] = bad_name3.id
    params[:name][:deprecated] = "false"
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: good_name.id)
    assert_no_emails
    assert_not(Name.exists?(bad_name3.id))
    assert(good_name.reload)
    assert_not(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(3, good_name.version)
    assert_equal(3, good_name.versions.size)

    # Fourth: merge accepted into accepted, but change to deprecated.
    assert_not(good_name.deprecated)
    assert_not(bad_name4.deprecated)
    params[:id] = bad_name4.id
    params[:name][:deprecated] = "true"
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: good_name.id)
    assert_no_emails
    assert_not(Name.exists?(bad_name4.id))
    assert(good_name.reload)
    assert(good_name.deprecated)
    assert_equal(good_author, good_name.author)
    assert_equal(good_text_name, good_name.text_name)
    assert_equal(4, good_name.version)
    assert_equal(4, good_name.versions.size)
  end

  # Test merge two names where the new name has description notes.
  def test_edit_name_merge_no_notes_into_description_notes
    old_name = names(:mergeable_no_notes)
    new_name = names(:mergeable_description_notes)
    notes = new_name.description.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        citation: "",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
    assert_equal(notes, new_name.description.notes)
  end

  # Test merge two names where the old name had notes.
  def test_edit_name_merge_matching_notes_2
    old_name = names(:russula_brevipes_author_notes)
    new_name = names(:conocybe_filaris)
    old_citation = old_name.citation
    old_notes = old_name.notes
    old_desc = old_name.description.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: "",
        rank: old_name.rank,
        citation: old_name.citation,
        notes: old_name.notes,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
    assert_equal("", new_name.author) # user explicitly set author to ""
    assert_equal(old_citation, new_name.citation)
    assert_equal(old_notes, new_name.notes)
    assert_not_nil(new_name.description)
    assert_equal(old_desc, new_name.description.notes)
  end

  def test_edit_name_merged_notes_include_notes_from_both_names
    old_name = names(:hygrocybe_russocoriacea_bad_author) # has notes
    new_name = names(:russula_brevipes_author_notes)
    original_notes = new_name.notes
    old_name_notes = old_name.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        citation: new_name.citation,
        notes: old_name.notes,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_match(original_notes, new_name.reload.notes)
    assert_match(old_name_notes, new_name.notes)
  end

  # Test merging two names, only one with observations.  Should work either
  # direction, but always keeping the name with observations.
  def test_edit_name_merge_one_with_observations
    old_name = names(:conocybe_filaris) # no observations
    new_name = names(:coprinus_comatus) # has observations
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: old_name.rank,
        citation: "",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
  end

  def test_edit_name_merge_one_with_observations_other_direction
    old_name = names(:coprinus_comatus) # has observations
    new_name = names(:conocybe_filaris) # no observations
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: old_name.rank,
        citation: "",
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: old_name.id)
    assert_no_emails
    assert(old_name.reload)
    assert_not(Name.exists?(new_name.id))
  end

  # Test merge two names that both start with notes.
  def test_edit_name_merge_both_notes
    old_name = names(:mergeable_description_notes)
    new_name = names(:mergeable_second_description_notes)
    old_notes = old_name.description.notes
    new_notes = new_name.description.notes
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: new_name.author,
        rank: new_name.rank,
        deprecated: (new_name.deprecated ? "true" : "false"),
        citation: ""
      }
    }
    login("rolf")
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_no_emails
    assert(new_name.reload)
    assert_not(Name.exists?(old_name.id))
    assert_equal(new_notes, new_name.description.notes)
    # Make sure old notes are still around.
    other_desc = (new_name.descriptions - [new_name.description]).first
    assert_equal(old_notes, other_desc.notes)
  end

  def test_edit_name_both_with_notes_and_namings
    old_name = names(:agaricus_campestros)
    new_name = names(:agaricus_campestras)
    new_versions = new_name.versions.size
    params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        author: old_name.author,
        rank: old_name.rank,
        deprecated: (old_name.deprecated ? "true" : "false")
      }
    }

    # Fails normally.
    login("rolf")
    post(:edit_name, params)
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Name, old_id: old_name.id, new_id: new_name.id)
    assert(old_name.reload)
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(1, new_name.namings.size)
    assert_equal(1, old_name.namings.size)
    assert_not_equal(new_name.namings[0], old_name.namings[0])

    # Try again in admin mode.
    make_admin
    post(:edit_name, params)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_name.id)
    assert_no_emails
    assert_raises(ActiveRecord::RecordNotFound) do
      assert(old_name.reload)
    end
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(2, new_name.namings.size)
  end

  # Prove that notification is moved to new_name
  # when old_name with notication is merged to new_name
  def test_edit_name_merge_with_notification
    note = notifications(:no_observation_notification)
    old_name = Name.find(note.obj_id)
    new_name = names(:fungi)
    login(old_name.user.name)
    make_admin(old_name.user.login)
    change_old_name_to_new_name_params = {
      id: old_name.id,
      name: {
        text_name: new_name.text_name,
        rank: :Genus,
        deprecated: "false"
      }
    }

    post(:edit_name, change_old_name_to_new_name_params)
    note.reload

    assert_equal(new_name.id, note.obj_id,
                 "Notification was not redirected to target of Name merger")
  end

  # Test that misspellings are handle right when merging.
  def test_edit_name_merge_with_misspellings
    login("rolf")
    name1 = names(:lactarius_alpinus)
    name2 = names(:lactarius_alpigenes)
    name3 = names(:lactarius_kuehneri)
    name4 = names(:lactarius_subalpinus)

    # First: merge Y into X, where Y is misspelling of X
    name2.correct_spelling = name1
    name2.change_deprecated(true)
    name2.save
    assert_not(name1.correct_spelling)
    assert_not(name1.deprecated)
    assert(name2.correct_spelling == name1)
    assert(name2.deprecated)
    params = {
      id: name2.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: :Species,
        deprecated: "true"
      }
    }
    post(:edit_name, params)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: name1.id)
    assert_no_emails
    assert_not(Name.exists?(name2.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert_not(name1.deprecated)

    # Second: merge Y into X, where X is misspelling of Y
    name1.correct_spelling = name3
    name1.change_deprecated(true)
    name1.save
    name3.correct_spelling = nil
    name3.change_deprecated(false)
    name3.save
    assert(name1.correct_spelling == name3)
    assert(name1.deprecated)
    assert_not(name3.correct_spelling)
    assert_not(name3.deprecated)
    params = {
      id: name3.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: :Species,
        deprecated: "false"
      }
    }
    post(:edit_name, params)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: name1.id)
    assert_no_emails
    assert_not(Name.exists?(name3.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert(name1.deprecated)

    # Third: merge Y into X, where X is misspelling of Z
    name1.correct_spelling = Name.first
    name1.change_deprecated(true)
    name1.save
    name4.correct_spelling = nil
    name4.change_deprecated(false)
    name4.save
    assert(name1.correct_spelling)
    assert(name1.correct_spelling != name4)
    assert(name1.deprecated)
    assert_not(name4.correct_spelling)
    assert_not(name4.deprecated)
    params = {
      id: name4.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: :Species,
        deprecated: "false"
      }
    }
    post(:edit_name, params)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: name1.id)
    assert_no_emails
    assert_not(Name.exists?(name4.id))
    assert(name1.reload)
    assert(name1.correct_spelling == Name.first)
    assert(name1.deprecated)
  end

  # Found this in the wild, it seems to have been fixed already, though...
  def test_edit_name_merge_authored_misspelt_into_unauthored_correctly_spelled
    login("rolf")

    name2 = Name.create!(
      text_name: "Russula sect. Compactae",
      search_name: "Russula sect. Compactae",
      sort_name: "Russula sect. Compactae",
      display_name: "**__Russula__** sect. **__Compactae__**",
      author: "",
      rank: :Section,
      deprecated: false,
      correct_spelling: nil
    )
    name1 = Name.create!(
      text_name: "Russula sect. Compactae",
      search_name: "Russula sect. Compactae Fr.",
      sort_name: "Russula sect. Compactae Fr.",
      display_name: "__Russula__ sect. __Compactae__ Fr.",
      author: "Fr.",
      rank: :Section,
      deprecated: true,
      correct_spelling: name2
    )
    params = {
      id: name2.id,
      name: {
        text_name: name1.text_name,
        author: name1.author,
        rank: :Section,
        deprecated: "false"
      }
    }
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: name1.id)
    assert_no_emails
    assert_not(Name.exists?(name2.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert(name1.deprecated)
    assert_equal("Russula sect. Compactae", name1.text_name)
    assert_equal("Fr.", name1.author)
  end

  # Another one found in the wild, probably already fixed.
  def test_edit_name_merge_authored_with_old_style_unauthored
    login("rolf")
    # Obsolete intrageneric Name, :Genus with rank & author in the author field.
    # (NameController no longer allows this.)
    old_style_name = Name.create!(
      text_name: "Amanita",
      search_name: "Amanita (sect. Vaginatae)",
      sort_name: "Amanita  (sect. Vaginatae)",
      display_name: "**__Amanita__** (sect. Vaginatae)",
      author: "(sect. Vaginatae)",
      rank: :Genus,
      deprecated: false,
      correct_spelling: nil
    )
    # New style. Uses correct rank, and puts rank text in text_name
    new_style_name = Name.create!(
      text_name: "Amanita sect. Vaginatae",
      search_name: "Amanita sect. Vaginatae (Fr.) Quél.",
      sort_name: "Amanita sect. Vaginatae  (Fr.)   Quél.",
      display_name: "**__Amanita__** sect. **__Vaginatae__** (Fr.) Quél.",
      author: "(Fr.) Quél.",
      rank: :Section,
      deprecated: false,
      correct_spelling: nil
    )
    params = {
      id: old_style_name.id,
      name: {
        text_name: new_style_name.text_name,
        author: new_style_name.author,
        rank: new_style_name.rank,
        deprecated: "false"
      }
    }
    post(:edit_name, params)

    assert_flash_success
    assert_redirected_to(action: :show_name, id: new_style_name.id)
    assert_no_emails
    assert_not(Name.exists?(old_style_name.id))
    assert(new_style_name.reload)
    assert_not(new_style_name.correct_spelling)
    assert_not(new_style_name.deprecated)
    assert_equal("Amanita sect. Vaginatae", new_style_name.text_name)
    assert_equal("(Fr.) Quél.", new_style_name.author)
  end

  # Another one found in the wild, probably already fixed.
  def test_edit_name_merge_authored_with_old_style_deprecated
    login("rolf")
    syn = Synonym.create
    name1 = Name.create!(
      text_name: "Cortinarius subgenus Sericeocybe",
      search_name: "Cortinarius subgenus Sericeocybe",
      sort_name: "Cortinarius subgenus Sericeocybe",
      display_name: "**__Cortinarius__** subg. **__Sericeocybe__**",
      author: "",
      rank: :Subgenus,
      deprecated: false,
      correct_spelling: nil,
      synonym: syn
    )
    # The old way to create an intrageneric Name, using the author field
    name2 = Name.create!(
      text_name: "Cortinarius",
      search_name: "Cortinarius (sub Genus Sericeocybe)",
      sort_name: "Cortinarius (sub Genus Sericeocybe)",
      display_name: "__Cortinarius__ (sub Genus Sericeocybe)",
      author: "(sub Genus Sericeocybe)",
      rank: :Genus,
      deprecated: true,
      correct_spelling: nil,
      synonym: syn
    )

    params = {
      id: name2.id,
      name: {
        text_name: "Cortinarius subg. Sericeocybe",
        author: "",
        rank: :Subgenus,
        deprecated: "false"
      }
    }
    post(:edit_name, params)
    assert_flash_success
    assert_redirected_to(action: :show_name, id: name1.id)
    assert_no_emails
    assert_not(Name.exists?(name2.id))
    assert(name1.reload)
    assert_not(name1.correct_spelling)
    assert_not(name1.deprecated)
    assert_equal("Cortinarius subgenus Sericeocybe", name1.text_name)
    assert_equal("", name1.author)
  end

  # ----------------------------
  #  Bulk names.
  # ----------------------------

  def test_update_bulk_names_nn_synonym
    new_name_str = "Amanita fergusonii"
    assert_nil(Name.find_by(text_name: new_name_str))
    new_synonym_str = "Amanita lanei"
    assert_nil(Name.find_by(text_name: new_synonym_str))
    params = {
      list: { members: "#{new_name_str} = #{new_synonym_str}" }
    }
    post_requires_login(:bulk_name_edit, params)
    assert_template(:bulk_name_edit, partial: "_form_list_feedback")
    assert_nil(Name.find_by(text_name: new_name_str))
    assert_nil(Name.find_by(text_name: new_synonym_str))
    assert_equal(10, rolf.reload.contribution)
  end

  def test_update_bulk_names_approved_nn_synonym
    new_name_str = "Amanita fergusonii"
    assert_nil(Name.find_by(text_name: new_name_str))
    new_synonym_str = "Amanita lanei"
    assert_nil(Name.find_by(text_name: new_synonym_str))
    params = {
      list: { members: "#{new_name_str} = #{new_synonym_str}" },
      approved_names: [new_name_str, new_synonym_str].join("\r\n")
    }
    login("rolf")
    post(:bulk_name_edit, params)
    assert_redirected_to(controller: :observer, action: "list_rss_logs")
    assert(new_name = Name.find_by(text_name: new_name_str))
    assert_equal(new_name_str, new_name.text_name)
    assert_equal("**__#{new_name_str}__**", new_name.display_name)
    assert_not(new_name.deprecated)
    assert_equal(:Species, new_name.rank)
    assert(synonym_name = Name.find_by(text_name: new_synonym_str))
    assert_equal(new_synonym_str, synonym_name.text_name)
    assert_equal("__#{new_synonym_str}__", synonym_name.display_name)
    assert(synonym_name.deprecated)
    assert_equal(:Species, synonym_name.rank)
    assert_not_nil(new_name.synonym_id)
    assert_equal(new_name.synonym_id, synonym_name.synonym_id)
  end

  def test_update_bulk_names_ee_synonym
    approved_name = names(:chlorophyllum_rachodes)
    synonym_name = names(:macrolepiota_rachodes)
    assert_not_equal(approved_name.synonym_id, synonym_name.synonym_id)
    assert_not(synonym_name.deprecated)
    params = {
      list: {
        members: "#{approved_name.search_name} = #{synonym_name.search_name}"
      }
    }
    login("rolf")
    post(:bulk_name_edit, params)
    assert_redirected_to(controller: :observer, action: "list_rss_logs")
    assert_not(approved_name.reload.deprecated)
    assert(synonym_name.reload.deprecated)
    assert_not_nil(approved_name.synonym_id)
    assert_equal(approved_name.synonym_id, synonym_name.synonym_id)
  end

  def test_update_bulk_names_eee_synonym
    approved_name = names(:lepiota_rachodes)
    synonym_name  = names(:lepiota_rhacodes)
    synonym_name2 = names(:chlorophyllum_rachodes)
    assert_nil(approved_name.synonym_id)
    assert_nil(synonym_name.synonym_id)
    assert_not_nil(synonym_name2.synonym_id)
    assert_not(approved_name.deprecated)
    assert_not(synonym_name.deprecated)
    assert_not(synonym_name2.deprecated)
    params = { list: {
      members:
        "#{approved_name.search_name} = #{synonym_name.search_name}\r\n" \
        "#{approved_name.search_name} = #{synonym_name2.search_name}"
    } }
    login("rolf")
    post(:bulk_name_edit, params)
    assert_redirected_to(controller: :observer, action: "list_rss_logs")
    assert_not(approved_name.reload.deprecated)
    assert(synonym_name.reload.deprecated)
    assert(synonym_name2.reload.deprecated)
    assert_not_nil(approved_name.synonym_id)
    assert_equal(approved_name.synonym_id, synonym_name.synonym_id)
    assert_equal(approved_name.synonym_id, synonym_name2.synonym_id)
  end

  def test_update_bulk_names_en_synonym
    approved_name = names(:chlorophyllum_rachodes)
    target_synonym_id = approved_name.synonym_id
    assert_not_nil(target_synonym_id)
    new_synonym_str = "New name Wilson"
    assert_nil(Name.find_by(search_name: new_synonym_str))
    params = {
      list: { members: "#{approved_name.search_name} = #{new_synonym_str}" },
      approved_names: [approved_name.search_name, new_synonym_str].join("\r\n")
    }
    login("rolf")
    post(:bulk_name_edit, params)
    assert_redirected_to(controller: :observer, action: "list_rss_logs")
    assert_not(approved_name.reload.deprecated)
    assert(synonym_name = Name.find_by(search_name: new_synonym_str))
    assert(synonym_name.deprecated)
    assert_equal(:Species, synonym_name.rank)
    assert_not_nil(approved_name.synonym_id)
    assert_equal(approved_name.synonym_id, synonym_name.synonym_id)
    assert_equal(target_synonym_id, approved_name.synonym_id)
  end

  def test_update_bulk_names_ne_synonym
    new_name_str = "New name Wilson"
    assert_nil(Name.find_by(search_name: new_name_str))
    synonym_name = names(:macrolepiota_rachodes)
    assert_not(synonym_name.deprecated)
    target_synonym = synonym_name.synonym
    assert(target_synonym)
    params = {
      list: { members: "#{new_name_str} = #{synonym_name.search_name}" },
      approved_names: [new_name_str, synonym_name.search_name].join("\r\n")
    }
    login("rolf")
    post(:bulk_name_edit, params)
    assert_redirected_to(controller: :observer, action: "list_rss_logs")
    assert(approved_name = Name.find_by(search_name: new_name_str))
    assert_not(approved_name.deprecated)
    assert_equal(:Species, approved_name.rank)
    assert(synonym_name.reload.deprecated)
    assert_not_nil(approved_name.synonym_id)
    assert_equal(approved_name.synonym_id, synonym_name.synonym_id)
    assert_equal(target_synonym, approved_name.synonym)
  end

  # Test a bug fix for the case of adding a subtaxon
  # when the parent taxon is duplicated due to different authors.
  def test_update_bulk_names_approved_for_dup_parents
    parent1 = names(:lentinellus_ursinus_author1)
    parent2 = names(:lentinellus_ursinus_author2)
    assert_not_equal(parent1, parent2)
    assert_equal(parent1.text_name, parent2.text_name)
    assert_not_equal(parent1.author, parent2.author)
    new_name_str = "#{parent1.text_name} f. robustus"
    assert_nil(Name.find_by(text_name: new_name_str))
    params = {
      list: { members: new_name_str.to_s },
      approved_names: new_name_str
    }
    login("rolf")
    post(:bulk_name_edit, params)
    assert_redirected_to(controller: :observer, action: "list_rss_logs")
    assert(Name.find_by(text_name: new_name_str))
  end

  # ----------------------------
  #  Synonyms.
  # ----------------------------

  # combine two Names that have no Synonym
  def test_transfer_synonyms_1_1
    selected_name = names(:lepiota_rachodes)
    assert_not(selected_name.deprecated)
    assert_nil(selected_name.synonym_id)
    selected_past_name_count = selected_name.versions.length
    selected_version = selected_name.version

    add_name = names(:lepiota_rhacodes)
    assert_not(add_name.deprecated)
    assert_equal("**__Lepiota rhacodes__** Vittad.", add_name.display_name)
    assert_nil(add_name.synonym_id)
    add_past_name_count = add_name.versions.length
    add_name_version = add_name.version

    params = {
      id: selected_name.id,
      synonym: { members: add_name.text_name },
      deprecate: { all: "1" }
    }
    post_requires_login(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert(add_name.reload.deprecated)
    assert_equal("__Lepiota rhacodes__ Vittad.", add_name.display_name)
    # past name should have been created
    assert_equal(add_past_name_count + 1, add_name.versions.length)
    assert(add_name.versions.latest.deprecated)
    assert_not_nil(add_synonym = add_name.synonym)
    assert_equal(add_name_version + 1, add_name.version)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_past_name_count, selected_name.versions.length)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)

    assert_not(names(:lepiota).reload.deprecated)
  end

  # combine two Names that have no Synonym and no deprecation
  def test_transfer_synonyms_1_1_nd
    selected_name = names(:lepiota_rachodes)
    assert_not(selected_name.deprecated)
    assert_nil(selected_name.synonym_id)
    selected_version = selected_name.version

    add_name = names(:lepiota_rhacodes)
    assert_not(add_name.deprecated)
    assert_nil(add_name.synonym_id)
    add_version = add_name.version

    params = {
      id: selected_name.id,
      synonym: { members: add_name.text_name },
      deprecate: { all: "0" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert_not(add_name.reload.deprecated)
    assert_not_nil(add_synonym = add_name.synonym)
    assert_equal(add_version, add_name.version)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)
  end

  # add new name string to Name with no Synonym but not approved
  def test_transfer_synonyms_1_0_na
    selected_name = names(:lepiota_rachodes)
    assert_not(selected_name.deprecated)
    assert_nil(selected_name.synonym_id)

    params = {
      id: selected_name.id,
      synonym: { members: "Lepiota rachodes var. rachodes" },
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_template(:change_synonyms, partial: "_form_synonyms")

    assert_nil(selected_name.reload.synonym_id)
    assert_not(selected_name.deprecated)
  end

  # add new name string to Name with no Synonym but approved
  def test_transfer_synonyms_1_0_a
    selected_name = names(:lepiota_rachodes)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym_id)

    params = {
      id: selected_name.id,
      synonym: { members: "Lepiota rachodes var. rachodes" },
      approved_names: "Lepiota rachodes var. rachodes",
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert_equal(selected_version, selected_name.reload.version)
    assert_not_nil(synonym = selected_name.synonym)
    assert_equal(2, synonym.names.length)
    synonym.names.each do |n|
      n == selected_name ? assert_not(n.deprecated) : assert(n.deprecated)
    end

    assert_not(names(:lepiota).reload.deprecated)
  end

  # add new name string to Name with no Synonym but approved
  def test_transfer_synonyms_1_00_a
    page_name = names(:lepiota_rachodes)
    assert_not(page_name.deprecated)
    assert_nil(page_name.synonym_id)

    params = {
      id: page_name.id,
      synonym: {
        members: "Lepiota rachodes var. rachodes\r\n" \
                    "Lepiota rhacodes var. rhacodes"
      },
      approved_names: [
        "Lepiota rachodes var. rachodes",
        "Lepiota rhacodes var. rhacodes"
      ].join("\r\n"),
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: page_name.id)

    assert_not(page_name.reload.deprecated)
    assert_not_nil(synonym = page_name.synonym)
    assert_equal(3, synonym.names.length)
    synonym.names.each do |n|
      n == page_name ? assert_not(n.deprecated) : assert(n.deprecated)
    end

    assert_not(names(:lepiota).reload.deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym
  def test_transfer_synonyms_n_1
    add_name = names(:lepiota_rachodes)
    assert_not(add_name.deprecated)
    assert_nil(add_name.synonym_id)
    add_version = add_name.version

    selected_name = names(:chlorophyllum_rachodes)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    params = {
      id: selected_name.id,
      synonym: { members: add_name.search_name },
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert(add_name.reload.deprecated)
    assert_not_nil(add_synonym = add_name.synonym)
    assert_equal(add_version + 1, add_name.version)
    assert_not(names(:lepiota).reload.deprecated)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(start_size + 1, add_synonym.names.size)

    assert_not(names(:chlorophyllum).reload.deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym
  # with the alternates checked
  def test_transfer_synonyms_n_1_c
    add_name = names(:lepiota_rachodes)
    assert_not(add_name.deprecated)
    add_version = add_name.version
    assert_nil(add_name.synonym_id)

    selected_name = names(:chlorophyllum_rachodes)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    selected_synonym.names.each do |n|
      next unless n != selected_name # Check all names not matching selected one

      assert_not(n.deprecated)
      split_name = n
      existing_synonyms[n.id.to_s] = "1"
    end
    assert_not_nil(split_name)

    params = {
      id: selected_name.id,
      synonym: { members: add_name.search_name },
      existing_synonyms: existing_synonyms,
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert(add_name.reload.deprecated)
    assert_equal(add_version + 1, add_name.version)
    assert_not_nil(add_synonym = add_name.synonym)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(start_size + 1, add_synonym.names.size)

    assert_not(split_name.reload.deprecated)
    assert_equal(add_synonym, split_name.synonym)

    assert_not(names(:lepiota).reload.deprecated)
    assert_not(names(:chlorophyllum).reload.deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym
  # with the alternates not checked
  def test_transfer_synonyms_n_1_nc
    add_name = names(:lepiota_rachodes)
    assert_not(add_name.deprecated)
    assert_nil(add_name.synonym_id)
    add_version = add_name.version

    selected_name = names(:chlorophyllum_rachodes)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)

    existing_synonyms = {}
    split_name = nil
    selected_synonym.names.each do |n|
      next unless n != selected_name

      assert_not(n.deprecated)
      split_name = n
      # Uncheck all names not matching the selected one
      existing_synonyms[n.id.to_s] = "0"
    end
    assert_not_nil(split_name)
    assert_not(split_name.deprecated)
    split_version = split_name.version

    params = {
      id: selected_name.id,
      synonym: { members: add_name.search_name },
      existing_synonyms: existing_synonyms,
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert(add_name.reload.deprecated)
    assert_equal(add_version + 1, add_name.version)
    assert_not_nil(add_synonym = add_name.synonym)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)

    assert_not(split_name.reload.deprecated)
    assert_equal(split_version, split_name.version)
    assert_nil(split_name.synonym_id)

    assert_not(names(:lepiota).reload.deprecated)
    assert_not(names(:chlorophyllum).reload.deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym
  # with no approved synonyms
  def test_transfer_synonyms_1_n_ns
    add_name = names(:chlorophyllum_rachodes)
    assert_not(add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = names(:lepiota_rachodes)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym_id)

    params = {
      id: selected_name.id,
      synonym: { members: add_name.search_name },
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_template(:change_synonyms, partial: "_form_synonyms")

    assert_not(add_name.reload.deprecated)
    assert_equal(add_version, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_nil(selected_synonym)

    assert_equal(start_size, add_synonym.names.size)
    assert_not(names(:lepiota).reload.deprecated)
    assert_not(names(:chlorophyllum).reload.deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym
  # with all approved synonyms
  def test_transfer_synonyms_1_n_s
    add_name = names(:chlorophyllum_rachodes)
    assert_not(add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = names(:lepiota_rachodes)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym_id)

    synonym_ids = add_synonym.names.map(&:id).join("/")
    params = {
      id: selected_name.id,
      synonym: { members: add_name.search_name },
      approved_synonyms: synonym_ids,
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert(add_name.reload.deprecated)
    assert_equal(add_version + 1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)

    assert_equal(start_size + 1, add_synonym.names.size)
    assert_not(names(:lepiota).reload.deprecated)
    assert_not(names(:chlorophyllum).reload.deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym
  # with all approved synonyms
  def test_transfer_synonyms_1_n_l
    add_name = names(:chlorophyllum_rachodes)
    assert_not(add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = names(:lepiota_rachodes)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym_id)

    synonym_names = add_synonym.names.map(&:search_name).join("\r\n")
    params = {
      id: selected_name.id,
      synonym: { members: synonym_names },
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert(add_name.reload.deprecated)
    assert_equal(add_version + 1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)

    assert_equal(start_size + 1, add_synonym.names.size)
    assert_not(names(:lepiota).reload.deprecated)
    assert_not(names(:chlorophyllum).reload.deprecated)
  end

  # combine two Names that each have Synonyms with no chosen names
  def test_transfer_synonyms_n_n_ns
    add_name = names(:chlorophyllum_rachodes)
    assert_not(add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = names(:macrolepiota_rachodes)
    assert_not(selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)

    params = {
      id: selected_name.id,
      synonym: { members: add_name.search_name },
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_template(:change_synonyms, partial: "_form_synonyms")

    assert_not(add_name.reload.deprecated)
    assert_not_nil(add_synonym = add_name.synonym)
    assert_equal(add_start_size, add_synonym.names.size)

    assert_not(selected_name.reload.deprecated)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_not_equal(add_synonym, selected_synonym)
    assert_equal(selected_start_size, selected_synonym.names.size)
  end

  # combine two Names that each have Synonyms with all chosen names
  def test_transfer_synonyms_n_n_s
    add_name = names(:chlorophyllum_rachodes)
    assert_not(add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = names(:macrolepiota_rachodes)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)

    synonym_ids = add_synonym.names.map(&:id).join("/")
    params = {
      id: selected_name.id,
      synonym: { members: add_name.search_name },
      approved_synonyms: synonym_ids,
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert(add_name.reload.deprecated)
    assert_equal(add_version + 1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size + selected_start_size, add_synonym.names.size)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
  end

  # combine two Names that each have Synonyms with all names listed
  def test_transfer_synonyms_n_n_l
    add_name = names(:chlorophyllum_rachodes)
    assert_not(add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = names(:macrolepiota_rachodes)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)

    synonym_names = add_synonym.names.map(&:search_name).join("\r\n")
    params = {
      id: selected_name.id,
      synonym: { members: synonym_names },
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert(add_name.reload.deprecated)
    assert_equal(add_version + 1, add_name.version)
    assert_not_nil(add_synonym = add_name.synonym)
    assert_equal(add_start_size + selected_start_size, add_synonym.names.size)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
  end

  # split off a single name from a name with multiple synonyms
  def test_transfer_synonyms_split_3_1
    selected_name = names(:lactarius_alpinus)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    selected_id = selected_name.id
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    # Must use "for" because kept_name is assigned in block and used later
    for n in selected_synonym.names
      next unless n.id != selected_id

      assert(n.deprecated)
      if split_name.nil? # Find the first different name and uncheck it
        split_name = n
        existing_synonyms[n.id.to_s] = "0"
      else
        kept_name = n
        existing_synonyms[n.id.to_s] = "1" # Check the rest
      end
    end
    split_version = split_name.version
    kept_version = kept_name.version
    params = {
      id: selected_name.id,
      synonym: { members: "" },
      existing_synonyms: existing_synonyms,
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert_equal(selected_version, selected_name.reload.version)
    assert_not(selected_name.deprecated)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(selected_start_size - 1, selected_synonym.names.size)

    assert(split_name.reload.deprecated)
    assert_equal(split_version, split_name.version)
    assert_nil(split_name.synonym_id)

    assert(kept_name.deprecated)
    assert_equal(kept_version, kept_name.version)
  end

  # split 4 synonymized names into two sets of synonyms with two members each
  def test_transfer_synonyms_split_2_2
    selected_name = names(:lactarius_alpinus)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_names = []
    count = 0
    selected_synonym.names.each do |n|
      next unless n != selected_name

      assert(n.deprecated)
      if count < 2 # Uncheck two names
        split_names.push(n)
        existing_synonyms[n.id.to_s] = "0"
      else
        existing_synonyms[n.id.to_s] = "1"
      end
      count += 1
    end
    assert_equal(2, split_names.length)
    assert_not_equal(split_names[0], split_names[1])

    params = {
      id: selected_name.id,
      synonym: { members: "" },
      existing_synonyms: existing_synonyms,
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert_not(selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(selected_start_size - 2, selected_synonym.names.size)

    assert(split_names[0].reload.deprecated)
    assert_not_nil(split_synonym = split_names[0].synonym)
    assert(split_names[1].reload.deprecated)
    assert_not_equal(split_names[0], split_names[1])
    assert_equal(split_synonym, split_names[1].synonym)
    assert_equal(2, split_synonym.names.size)
  end

  # take four synonymized names and separate off one
  def test_transfer_synonyms_split_1_3
    selected_name = names(:lactarius_alpinus)
    assert_not(selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    selected_synonym.names.each do |n|
      next unless n != selected_name

      assert(n.deprecated)
      split_name = n
      # Uncheck all names not matching the selected one
      existing_synonyms[n.id.to_s] = "0"
    end
    assert_not_nil(split_name)
    split_version = split_name.version

    params = {
      id: selected_name.id,
      synonym: { members: "" },
      existing_synonyms: existing_synonyms,
      deprecate: { all: "1" }
    }
    login("rolf")
    post(:change_synonyms, params)
    assert_redirected_to(action: :show_name, id: selected_name.id)

    assert_equal(selected_version, selected_name.reload.version)
    assert_not(selected_name.deprecated)
    assert_nil(selected_name.synonym)

    assert(split_name.reload.deprecated)
    assert_equal(split_version, split_name.version)
    assert_not_nil(split_synonym = split_name.synonym)
    assert_equal(selected_start_size - 1, split_synonym.names.size)
  end

  def test_change_synonyms_locked
    name = Name.where(locked: true).first
    name2 = names(:agaricus_campestris)
    synonym = Synonym.create!
    Name.update(name.id, synonym_id: synonym.id)
    Name.update(name2.id, synonym_id: synonym.id)
    existing_synonyms = {}
    name.reload.synonyms.each do |n|
      existing_synonyms[n.id.to_s] = "0"
    end
    params = {
      id: name.id,
      synonym: { members: "" },
      existing_synonyms: existing_synonyms,
      deprecate: { all: "" }
    }

    login("rolf")
    get(:change_synonyms, id: name.id)
    assert_response(:redirect)
    post(:change_synonyms, params)
    assert_flash_error
    assert_not_nil(name.reload.synonym_id)

    make_admin("mary")
    get(:change_synonyms, id: name.id)
    assert_response(:success)
    post(:change_synonyms, params)
    assert_nil(name.reload.synonym_id)
  end

  # ----------------------------
  #  Deprecation.
  # ----------------------------

  # deprecate an existing unique name with another existing name
  def test_do_deprecation
    old_name = names(:lepiota_rachodes)
    assert_not(old_name.deprecated)
    assert_nil(old_name.synonym_id)
    old_past_name_count = old_name.versions.length
    old_version = old_name.version

    new_name = names(:chlorophyllum_rachodes)
    assert_not(new_name.deprecated)
    assert_not_nil(new_name.synonym_id)
    new_synonym_length = new_name.synonyms.size
    new_past_name_count = new_name.versions.length
    new_version = new_name.version

    params = {
      id: old_name.id,
      proposed: { name: new_name.text_name },
      comment: { comment: "Don't like this name" }
    }
    post_requires_login(:deprecate_name, params)
    assert_redirected_to(action: :show_name, id: old_name.id)

    assert(old_name.reload.deprecated)
    assert_equal(old_past_name_count + 1, old_name.versions.length)
    assert(old_name.versions.latest.deprecated)
    assert_not_nil(old_synonym = old_name.synonym)
    assert_equal(old_version + 1, old_name.version)

    assert_not(new_name.reload.deprecated)
    assert_equal(new_past_name_count, new_name.versions.length)
    assert_not_nil(new_synonym = new_name.synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(new_synonym_length + 1, new_synonym.names.size)
    assert_equal(new_version, new_name.version)

    comment = Comment.last
    assert_equal("Name", comment.target_type)
    assert_equal(old_name.id, comment.target_id)
    assert_match(/deprecat/i, comment.summary)
    assert_equal("Don't like this name", comment.comment)
  end

  # deprecate an existing unique name with an ambiguous name
  def test_do_deprecation_ambiguous
    old_name = names(:lepiota_rachodes)
    assert_not(old_name.deprecated)
    assert_nil(old_name.synonym_id)
    old_past_name_count = old_name.versions.length

    new_name = names(:amanita_baccata_arora) # Ambiguous text name
    assert_not(new_name.deprecated)
    assert_nil(new_name.synonym_id)
    new_past_name_count = new_name.versions.length

    comments = Comment.count

    params = {
      id: old_name.id,
      proposed: { name: new_name.text_name },
      comment: { comment: "" }
    }
    login("rolf")
    post(:deprecate_name, params)
    assert_template(:deprecate_name, partial: "_form_name_feedback")
    # Fail since name can't be disambiguated

    assert_not(old_name.reload.deprecated)
    assert_equal(old_past_name_count, old_name.versions.length)
    assert_nil(old_name.synonym_id)

    assert_not(new_name.reload.deprecated)
    assert_equal(new_past_name_count, new_name.versions.length)
    assert_nil(new_name.synonym_id)

    assert_equal(comments, Comment.count)
  end

  # deprecate an existing unique name with an ambiguous name,
  # but using :chosen_name to disambiguate
  def test_do_deprecation_chosen
    old_name = names(:lepiota_rachodes)
    assert_not(old_name.deprecated)
    assert_nil(old_name.synonym_id)
    old_past_name_count = old_name.versions.length

    new_name = names(:amanita_baccata_arora) # Ambiguous text name
    assert_not(new_name.deprecated)
    assert_nil(new_name.synonym_id)
    new_past_name_count = new_name.versions.length

    params = {
      id: old_name.id,
      proposed: { name: new_name.text_name },
      chosen_name: { name_id: new_name.id },
      comment: { comment: "Don't like this name" }
    }
    login("rolf")
    post(:deprecate_name, params)
    assert_redirected_to(action: :show_name, id: old_name.id)

    assert(old_name.reload.deprecated)
    assert_equal(old_past_name_count + 1, old_name.versions.length)
    assert(old_name.versions.latest.deprecated)
    assert_not_nil(old_synonym = old_name.synonym)

    assert_not(new_name.reload.deprecated)
    assert_equal(new_past_name_count, new_name.versions.length)
    assert_not_nil(new_synonym = new_name.synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(2, new_synonym.names.size)
  end

  # deprecate an existing unique name with an ambiguous name
  def test_do_deprecation_new_name
    old_name = names(:lepiota_rachodes)
    assert_not(old_name.deprecated)
    assert_nil(old_name.synonym_id)
    old_past_name_count = old_name.versions.length

    new_name_str = "New name"

    params = {
      id: old_name.id,
      proposed: { name: new_name_str },
      comment: { comment: "Don't like this name" }
    }
    login("rolf")
    post(:deprecate_name, params)
    assert_template(:deprecate_name, partial: "_form_name_feedback")
    # Fail since new name is not approved

    assert_not(old_name.reload.deprecated)
    assert_equal(old_past_name_count, old_name.versions.length)
    assert_nil(old_name.synonym_id)
  end

  # deprecate an existing unique name with an ambiguous name,
  # but using :chosen_name to disambiguate
  def test_do_deprecation_approved_new_name
    old_name = names(:lepiota_rachodes)
    assert_not(old_name.deprecated)
    assert_nil(old_name.synonym_id)
    old_past_name_count = old_name.versions.length

    new_name_str = "New name"

    params = {
      id: old_name.id,
      proposed: { name: new_name_str },
      approved_name: new_name_str,
      comment: { comment: "Don't like this name" }
    }
    login("rolf")
    post(:deprecate_name, params)
    assert_redirected_to(action: :show_name, id: old_name.id)

    assert(old_name.reload.deprecated)
    # past name should have been created# past name should have been created
    assert_equal(old_past_name_count + 1, old_name.versions.length)
    assert(old_name.versions.latest.deprecated)
    assert_not_nil(old_synonym = old_name.synonym)

    new_name = Name.find_by(text_name: new_name_str)
    assert_not(new_name.deprecated)
    assert_not_nil(new_synonym = new_name.synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(2, new_synonym.names.size)
  end

  def test_deprecate_name_locked
    name = Name.where(locked: true).first
    name2 = names(:agaricus_campestris)
    name.change_deprecated(false)
    name.save
    params = {
      id: name.id,
      proposed: { name: name2.search_name },
      approved_name: name2.search_name,
      comment: { comment: "" }
    }

    login("rolf")
    get(:deprecate_name, id: name.id)
    assert_response(:redirect)
    post(:deprecate_name, params)
    assert_flash_error
    assert_false(name.reload.deprecated)

    make_admin("mary")
    get(:deprecate_name, id: name.id)
    assert_response(:success)
    post(:deprecate_name, params)
    assert_true(name.reload.deprecated)
  end

  # ----------------------------
  #  Approval.
  # ----------------------------

  # approve a deprecated name
  def test_do_approval_default
    old_name = names(:lactarius_alpigenes)
    assert(old_name.deprecated)
    assert(old_name.synonym_id)
    old_past_name_count = old_name.versions.length
    old_version = old_name.version
    approved_synonyms = old_name.approved_synonyms

    params = {
      id: old_name.id,
      deprecate: { others: "1" },
      comment: { comment: "Prefer this name" }
    }
    post_requires_login(:approve_name, params)
    assert_redirected_to(action: :show_name, id: old_name.id)

    assert_not(old_name.reload.deprecated)
    assert_equal(old_past_name_count + 1, old_name.versions.length)
    assert_not(old_name.versions.latest.deprecated)
    assert_equal(old_version + 1, old_name.version)

    approved_synonyms.each { |n| assert(n.reload.deprecated) }

    comment = Comment.last
    assert_equal("Name", comment.target_type)
    assert_equal(old_name.id, comment.target_id)
    assert_match(/approve/i, comment.summary)
    assert_equal("Prefer this name", comment.comment)
  end

  # approve a deprecated name, but don't deprecate the synonyms
  def test_do_approval_no_deprecate
    old_name = names(:lactarius_alpigenes)
    assert(old_name.deprecated)
    assert(old_name.synonym_id)
    old_past_name_count = old_name.versions.length
    approved_synonyms = old_name.approved_synonyms

    comments = Comment.count

    params = {
      id: old_name.id,
      deprecate: { others: "0" },
      comment: { comment: "" }
    }
    login("rolf")
    post(:approve_name, params)
    assert_redirected_to(action: :show_name, id: old_name.id)

    assert_not(old_name.reload.deprecated)
    assert_equal(old_past_name_count + 1, old_name.versions.length)
    assert_not(old_name.versions.latest.deprecated)

    approved_synonyms.each { |n| assert_not(n.reload.deprecated) }
    assert_equal(comments, Comment.count)
  end

  def test_approve_name_locked
    name = Name.where(locked: true).first
    name.change_deprecated(true)
    name.save
    params = {
      id: name.id,
      deprecate: { others: "0" },
      comment: { comment: "" }
    }

    login("rolf")
    get(:approve_name, id: name.id)
    assert_response(:redirect)
    post(:approve_name, params)
    assert_flash_error
    assert_true(name.reload.deprecated)

    make_admin("mary")
    get(:approve_name, id: name.id)
    assert_response(:success)
    post(:approve_name, params)
    assert_false(name.reload.deprecated)
  end

  # ----------------------------
  #  Naming Notifications.
  # ----------------------------

  def test_email_tracking
    name = names(:coprinus_comatus)
    params = { id: name.id.to_s }
    requires_login(:email_tracking, params)
    assert_template(:email_tracking)
    assert_form_action(action: "email_tracking", id: name.id.to_s)
  end

  def test_email_tracking_enable_no_note
    name = names(:conocybe_filaris)
    count_before = Notification.count
    flavor = Notification.flavors[:name]
    notification = Notification.
                   find_by(flavor: flavor, obj_id: name.id, user_id: rolf.id)
    assert_nil(notification)
    params = {
      id: name.id,
      commit: :ENABLE.t,
      notification: {
        note_template: ""
      }
    }
    post_requires_login(:email_tracking, params)
    # This is needed before the next find for some reason
    count_after = Notification.count
    assert_equal(count_before + 1, count_after)
    notification = Notification.
                   find_by(flavor: flavor, obj_id: name.id, user_id: rolf.id)
    assert(notification)
    assert_nil(notification.note_template)
    assert_nil(
      notification.calc_note(user: rolf,
                             naming: namings(:coprinus_comatus_naming))
    )
  end

  def test_email_tracking_enable_with_note
    name = names(:conocybe_filaris)
    count_before = Notification.count
    flavor = Notification.flavors[:name]
    notification = Notification.
                   find_by(flavor: flavor, obj_id: name.id, user_id: rolf.id)
    assert_nil(notification)
    params = {
      id: name.id,
      commit: :ENABLE.t,
      notification: {
        note_template: "A note about :observation from :observer"
      }
    }
    login("rolf")
    post(:email_tracking, params)
    assert_redirected_to(action: :show_name, id: name.id)
    # This is needed before the next find for some reason
    count_after = Notification.count
    assert_equal(count_before + 1, count_after)
    notification = Notification.
                   find_by(flavor: flavor, obj_id: name.id, user_id: rolf.id)
    assert(notification)
    assert(notification.note_template)
    assert(notification.calc_note(user: mary,
                                  naming: namings(:coprinus_comatus_naming)))
  end

  def test_email_tracking_update_add_note
    name = names(:coprinus_comatus)
    count_before = Notification.count
    flavor = Notification.flavors[:name]
    notification = Notification.
                   find_by(flavor: flavor, obj_id: name.id, user_id: rolf.id)
    assert(notification)
    assert_nil(notification.note_template)
    params = {
      id: name.id,
      commit: "Update",
      notification: {
        note_template: "A note about :observation from :observer"
      }
    }
    login("rolf")
    post(:email_tracking, params)
    assert_redirected_to(action: :show_name, id: name.id)
    # This is needed before the next find for some reason
    count_after = Notification.count
    assert_equal(count_before, count_after)
    notification = Notification.
                   find_by(flavor: flavor, obj_id: name.id, user_id: rolf.id)
    assert(notification)
    assert(notification.note_template)
    assert(notification.calc_note(user: rolf,
                                  naming: namings(:coprinus_comatus_naming)))
  end

  def test_email_tracking_disable
    name = names(:coprinus_comatus)
    flavor = Notification.flavors[:name]
    notification = Notification.
                   find_by(flavor: flavor, obj_id: name.id, user_id: rolf.id)
    assert(notification)
    params = {
      id: name.id,
      commit: :DISABLE.t,
      notification: {
        note_template: "A note about :observation from :observer"
      }
    }
    login("rolf")
    post(:email_tracking, params)
    assert_redirected_to(action: :show_name, id: name.id)
    notification = Notification.
                   find_by(flavor: :name, obj_id: name.id, user_id: rolf.id)
    assert_nil(notification)
  end

  # ----------------------------
  #  Review status.
  # ----------------------------

  def test_set_review_status_reviewer
    desc = name_descriptions(:coprinus_comatus_desc)
    assert_equal(:unreviewed, desc.review_status)
    assert(rolf.in_group?("reviewers"))
    params = {
      id: desc.id,
      value: "vetted"
    }
    post_requires_login(:set_review_status, params)
    assert_redirected_to(action: :show_name, id: desc.name_id)
    assert_equal(:vetted, desc.reload.review_status)
  end

  def test_set_review_status_non_reviewer
    desc = name_descriptions(:coprinus_comatus_desc)
    assert_equal(:unreviewed, desc.review_status)
    assert_not(mary.in_group?("reviewers"))
    params = {
      id: desc.id,
      value: "vetted"
    }
    post_requires_login(:set_review_status, params, "mary")
    assert_redirected_to(action: :show_name, id: desc.name_id)
    assert_equal(:unreviewed, desc.reload.review_status)
  end

  # ----------------------------
  #  Interest.
  # ----------------------------

  def test_interest_in_show_name
    peltigera = names(:peltigera)
    login("rolf")

    # No interest in this name yet.
    get_with_dump(:show_name, id: peltigera.id)
    assert_response(:success)
    assert_image_link_in_html(/watch\d*.png/,
                              controller: "interest", action: "set_interest",
                              type: "Name", id: peltigera.id, state: 1)
    assert_image_link_in_html(/ignore\d*.png/,
                              controller: "interest", action: "set_interest",
                              type: "Name", id: peltigera.id, state: -1)

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.create(target: peltigera, user: rolf, state: true)
    get_with_dump(:show_name, id: peltigera.id)
    assert_response(:success)
    assert_image_link_in_html(/halfopen\d*.png/,
                              controller: "interest", action: "set_interest",
                              type: "Name", id: peltigera.id, state: 0)
    assert_image_link_in_html(/ignore\d*.png/,
                              controller: "interest", action: "set_interest",
                              type: "Name", id: peltigera.id, state: -1)

    # Destroy that interest, create new one with interest off.
    Interest.where(user_id: rolf.id).last.destroy
    Interest.create(target: peltigera, user: rolf, state: false)
    get_with_dump(:show_name, id: peltigera.id)
    assert_response(:success)
    assert_image_link_in_html(/halfopen\d*.png/,
                              controller: "interest", action: "set_interest",
                              type: "Name", id: peltigera.id, state: 0)
    assert_image_link_in_html(/watch\d*.png/,
                              controller: "interest", action: "set_interest",
                              type: "Name", id: peltigera.id, state: 1)
  end

  # ----------------------------
  #  Test project drafts.
  # ----------------------------

  # Ensure that draft owner can see a draft they own
  def test_show_draft
    draft = name_descriptions(:draft_coprinus_comatus)
    login(draft.user.login)
    get_with_dump(:show_name_description, id: draft.id)
    assert_template(:show_name_description, partial: "_show_description")
  end

  # Ensure that an admin can see a draft they don't own
  def test_show_draft_admin
    draft = name_descriptions(:draft_coprinus_comatus)
    assert_not_equal(draft.user, mary)
    login(mary.login)
    get_with_dump(:show_name_description, id: draft.id)
    assert_template(:show_name_description, partial: "_show_description")
  end

  # Ensure that an member can see a draft they don't own
  def test_show_draft_member
    draft = name_descriptions(:draft_agaricus_campestris)
    assert_not_equal(draft.user, katrina)
    login(katrina.login)
    get_with_dump(:show_name_description, id: draft.id)
    assert_template(:show_name_description, partial: "_show_description")
  end

  # Ensure that a non-member cannot see a draft
  def test_show_draft_non_member
    project = projects(:eol_project)
    draft = name_descriptions(:draft_agaricus_campestris)
    assert(draft.belongs_to_project?(project))
    assert_not(project.is_member?(dick))
    login(dick.login)
    get_with_dump(:show_name_description, id: draft.id)
    assert_redirected_to(project.show_link_args)
  end

  def test_create_draft_member
    create_draft_tester(projects(:eol_project),
                        names(:coprinus_comatus), katrina)
  end

  def test_create_draft_admin
    create_draft_tester(projects(:eol_project),
                        names(:coprinus_comatus), mary)
  end

  def test_create_draft_not_member
    create_draft_tester(projects(:eol_project),
                        names(:agaricus_campestris), dick, false)
  end

  def test_edit_draft
    edit_draft_tester(name_descriptions(:draft_coprinus_comatus))
  end

  def test_edit_draft_admin
    assert(projects(:eol_project).is_admin?(mary))
    assert_equal("EOL Project",
                 name_descriptions(:draft_coprinus_comatus).source_name)
    edit_draft_tester(name_descriptions(:draft_coprinus_comatus), mary)
  end

  def test_edit_draft_member
    assert(projects(:eol_project).is_member?(katrina))
    assert_equal("EOL Project",
                 name_descriptions(:draft_agaricus_campestris).source_name)
    edit_draft_tester(name_descriptions(:draft_agaricus_campestris),
                      katrina, false)
  end

  def test_edit_draft_non_member
    assert_not(projects(:eol_project).is_member?(dick))
    assert_equal("EOL Project",
                 name_descriptions(:draft_coprinus_comatus).source_name)
    edit_draft_tester(name_descriptions(:draft_coprinus_comatus),
                      dick, false, false)
  end

  def test_edit_draft_post_owner
    edit_draft_post_helper(name_descriptions(:draft_coprinus_comatus),
                           rolf)
  end

  def test_edit_draft_post_admin
    edit_draft_post_helper(name_descriptions(:draft_coprinus_comatus),
                           mary)
  end

  def test_edit_draft_post_member
    edit_draft_post_helper(name_descriptions(:draft_agaricus_campestris),
                           katrina, permission: false)
  end

  def test_edit_draft_post_non_member
    edit_draft_post_helper(name_descriptions(:draft_agaricus_campestris),
                           dick, permission: false)
  end

  def test_edit_draft_post_bad_classification
    edit_draft_post_helper(
      name_descriptions(:draft_coprinus_comatus),
      rolf,
      params: { classification: "**Domain**: Eukarya" },
      permission: true,
      success: false
    )
  end

  def test_make_description_default
    desc = name_descriptions(:peltigera_alt_desc)
    assert_not_equal(desc, desc.parent.description)
    make_description_default_helper(desc)
    desc.parent.reload
    assert_equal(desc, desc.parent.description)
  end

  def test_non_public_description_cannot_be_default
    desc = name_descriptions(:peltigera_user_desc)
    current_default = desc.parent.description
    make_description_default_helper(desc)
    desc.parent.reload
    assert_not_equal(desc, desc.parent.description)
    assert_equal(current_default, desc.parent.description)
  end

  # Owner can publish.
  def test_publish_draft
    publish_draft_helper(name_descriptions(:draft_coprinus_comatus), nil,
                         :merged, false)
  end

  # Admin can, too.
  def test_publish_draft_admin
    publish_draft_helper(name_descriptions(:draft_coprinus_comatus), mary,
                         :merged, false)
  end

  # Other members cannot.
  def test_publish_draft_member
    publish_draft_helper(name_descriptions(:draft_agaricus_campestris), katrina,
                         false, false)
  end

  # Non-members certainly can't.
  def test_publish_draft_non_member
    publish_draft_helper(
      name_descriptions(:draft_agaricus_campestris), dick, false, false
    )
  end

  # Non-members certainly can't.
  def test_publish_draft_conflict
    draft = name_descriptions(:draft_coprinus_comatus)
    # Create a simple public description to cause conflict.
    name = draft.name
    name.description = desc = NameDescription.create!(
      name: name,
      user: rolf,
      source_type: :public,
      source_name: "",
      public: true,
      gen_desc: "Pre-existing general description."
    )
    name.save
    desc.admin_groups << UserGroup.reviewers
    desc.writer_groups << UserGroup.all_users
    desc.reader_groups << UserGroup.all_users
    # It should make the draft both public and default, "true" below tells it
    # that the default gen_desc should look like the draft's after done.  No
    # more conflicts.
    publish_draft_helper(draft.reload, nil, true, false)
  end

  def test_destroy_draft_owner
    destroy_draft_helper(name_descriptions(:draft_coprinus_comatus), rolf)
  end

  def test_destroy_draft_admin
    destroy_draft_helper(name_descriptions(:draft_coprinus_comatus), mary)
  end

  def test_destroy_draft_member
    destroy_draft_helper(
      name_descriptions(:draft_agaricus_campestris), katrina, false
    )
  end

  def test_destroy_draft_non_member
    destroy_draft_helper(
      name_descriptions(:draft_agaricus_campestris), dick, false
    )
  end

  # ------------------------------
  #  Test creating descriptions.
  # ------------------------------

  def test_create_description_load_form_no_desc_yet
    name = names(:conocybe_filaris)
    assert_equal(0, name.descriptions.length)
    params = { id: name.id }

    # Make sure it requires login.
    requires_login(:create_name_description, params)
    desc = assigns(:description)
    assert_equal(:public, desc.source_type)
    assert_equal("", desc.source_name.to_s)
    assert_equal(true, desc.public)
    assert_equal(true, desc.public_write)

    # Test draft creation by project member.
    login("rolf") # member
    project = projects(:eol_project)
    get(:create_name_description, params.merge(project: project.id))
    assert_template(:create_name_description, partial: "_form_name_description")
    desc = assigns(:description)
    assert_equal(:project, desc.source_type)
    assert_equal(project.title, desc.source_name)
    assert_equal(false, desc.public)
    assert_equal(false, desc.public_write)

    # Test draft creation by project non-member.
    login("dick")
    get(:create_name_description, params.merge(project: project.id))
    assert_redirected_to(controller: "project", action: "show_project",
                         id: project.id)
    assert_flash_error
  end

  def test_create_description_load_form_already_has_desc
    name = names(:peltigera)
    assert_not_equal(0, name.descriptions.length)
    params = { id: name.id }

    # Make sure it requires login.
    requires_login(:create_name_description, params)
    desc = assigns(:description)
    assert_equal(:public, desc.source_type)
    assert_equal("", desc.source_name.to_s)
    assert_equal(true, desc.public)
    assert_equal(true, desc.public_write)

    # Test draft creation by project member.
    login("katrina") # member
    project = projects(:eol_project)
    get(:create_name_description, params.merge(project: project.id))
    assert_template(:create_name_description, partial: "_form_name_description")
    desc = assigns(:description)
    assert_equal(:project, desc.source_type)
    assert_equal(project.title, desc.source_name)
    assert_equal(false, desc.public)
    assert_equal(false, desc.public_write)

    # Test draft creation by project non-member.
    login("dick")
    get(:create_name_description, params.merge(project: project.id))
    assert_redirected_to(controller: "project",
                         action: "show_project",
                         id: project.id)
    assert_flash_error

    # Test clone of private description if not reader.
    other = name_descriptions(:peltigera_user_desc)
    login("katrina") # random user
    get(:create_name_description, params.merge(clone: other.id))
    assert_redirected_to(action: :show_name, id: name.id)
    assert_flash_error

    # Test clone of private description if can read.
    login("dick") # reader
    get(:create_name_description, params.merge(clone: other.id))
    assert_template(:create_name_description, partial: "_form_name_description")
    desc = assigns(:description)
    assert_equal(:user, desc.source_type)
    assert_equal("", desc.source_name.to_s)
    assert_equal(false, desc.public)
    assert_equal(false, desc.public_write)
  end

  def test_create_name_description_public
    # Minimum args.
    params = {
      description: empty_notes.merge(
        source_type: :public,
        source_name: "",
        public: "1",
        public_write: "1"
      )
    }

    # No desc yet -> make new desc default.
    name = names(:conocybe_filaris)
    assert_equal(0, name.descriptions.length)
    post(:create_name_description, params)
    assert_response(:redirect)
    login("dick")
    params[:id] = name.id
    post(:create_name_description, params)
    assert_flash_success
    desc = NameDescription.last
    assert_redirected_to(action: :show_name_description, id: desc.id)
    name.reload
    assert_objs_equal(desc, name.description)
    assert_obj_list_equal([desc], name.descriptions)
    assert_equal(:public, desc.source_type)
    assert_equal("", desc.source_name.to_s)
    assert_equal(true, desc.public)
    assert_equal(true, desc.public_write)
    assert_obj_list_equal([UserGroup.reviewers], desc.admin_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.writer_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.reader_groups)

    # Already have default, try to make public desc private -> warn and make
    # public but not default.
    name = names(:coprinus_comatus)
    assert(default = name.description)
    assert_not_equal(0, name.descriptions.length)
    params[:id] = name.id
    params[:description][:public]       = "0"
    params[:description][:public_write] = "0"
    params[:description][:source_name]  = "Alternate Description"
    post(:create_name_description, params)
    assert_flash_warning # tried to make it private
    desc = NameDescription.last
    assert_redirected_to(action: :show_name_description, id: desc.id)
    name.reload
    assert_objs_equal(default, name.description)
    assert_true(name.descriptions.include?(desc))
    assert_equal(:public, desc.source_type)
    assert_equal("Alternate Description", desc.source_name.to_s)
    assert_obj_list_equal([UserGroup.reviewers], desc.admin_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.writer_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.reader_groups)
    assert_equal(true, desc.public)
    assert_equal(true, desc.public_write)
  end

  def test_create_name_description_bogus_classification
    name = names(:agaricus_campestris)
    login("dick")

    bad_class = "*Order*: Agaricales\r\nFamily: Agaricaceae"
    good_class  = "Family: Agaricaceae\r\nOrder: Agaricales"
    final_class = "Order: _Agaricales_\r\nFamily: _Agaricaceae_"

    params = {
      id: name.id,
      description: empty_notes.merge(
        source_type: :public,
        source_name: "",
        public: "1",
        public_write: "1"
      )
    }

    params[:description][:classification] = bad_class
    post(:create_name_description, params)
    assert_flash_error
    assert_template(:create_name_description, partial: "_form_name_description")

    params[:description][:classification] = good_class
    post(:create_name_description, params)
    assert_flash_success
    desc = NameDescription.last
    assert_redirected_to(action: :show_name_description, id: desc.id)

    name.reload
    assert_equal(final_class, name.classification)
    assert_equal(final_class, desc.classification)
  end

  def test_create_name_description_source
    login("dick")

    name = names(:conocybe_filaris)
    assert_nil(name.description)
    assert_equal(0, name.descriptions.length)

    params = {
      id: name.id,
      description: empty_notes.merge(
        source_type: :source,
        source_name: "Mushrooms Demystified",
        public: "0",
        public_write: "0"
      )
    }

    post(:create_name_description, params)
    assert_flash_success
    desc = NameDescription.last
    assert_redirected_to(action: :show_name_description, id: desc.id)

    name.reload
    assert_nil(name.description)
    assert_true(name.descriptions.include?(desc))
    assert_equal(:source, desc.source_type)
    assert_equal("Mushrooms Demystified", desc.source_name)
    assert_false(desc.public)
    assert_false(desc.public_write)
    assert_obj_list_equal([UserGroup.one_user(dick)], desc.admin_groups)
    assert_obj_list_equal([UserGroup.one_user(dick)], desc.writer_groups)
    assert_obj_list_equal([UserGroup.one_user(dick)], desc.reader_groups)
  end

  # -----------------------------------
  #  Test classification propagation.
  # -----------------------------------

  def test_refresh_classification
    genus = names(:coprinus)
    child = names(:coprinus_comatus)
    val   = genus.classification
    time  = genus.updated_at
    assert_equal(val, child.classification)
    assert_equal(val, child.description.classification)
    assert_equal(time, child.updated_at)
    assert_equal(time, child.description.updated_at)

    # Make sure bogus requests don't crash.
    login("rolf")
    get(:refresh_classification)
    get(:refresh_classification, id: 666)
    get(:refresh_classification, id: "bogus")
    get(:refresh_classification, id: genus.id)
    get(:refresh_classification, id: child.id) # no change!
    assert_equal(val, genus.reload.classification)
    assert_equal(val, genus.description.reload.classification)
    assert_equal(val, child.reload.classification)
    assert_equal(val, child.description.reload.classification)
    assert_equal(time, genus.updated_at)
    assert_equal(time, genus.description.updated_at)
    assert_equal(time, child.updated_at)
    assert_equal(time, child.description.updated_at)

    # Make sure have to be logged in. (update_column should avoid callbacks)
    new_val = names(:peltigera).classification
    # disable cop because we're trying to avoid callbacks
    # rubocop:disable Rails/SkipsModelValidations
    child.update_columns(classification: new_val)
    child.description.update_columns(classification: new_val)
    # rubocop:enable Rails/SkipsModelValidations
    logout
    get(:refresh_classification, id: child.id)
    assert_equal(new_val, child.reload.classification)
    assert_equal(time, child.updated_at)

    # Now finally do it right and make sure it makes correct changes.
    login("rolf")
    get(:refresh_classification, id: child.id)
    assert_equal(val, child.reload.classification)
    assert_not_equal(time, child.updated_at)
  end

  def test_propagate_classification
    genus = names(:coprinus)
    child = names(:coprinus_comatus)
    val   = genus.classification
    assert_equal(val, child.classification)
    assert_equal(val, child.description.classification)

    # Make sure bogus requests don't crash.
    login("rolf")
    get(:propagate_classification)
    get(:propagate_classification, id: 666)
    get(:propagate_classification, id: "bogus")
    get(:propagate_classification, id: child.id)
    get(:propagate_classification, id: names(:ascomycota).id)
    assert_equal(val, genus.reload.classification)
    assert_equal(val, genus.description.reload.classification)
    assert_equal(val, child.reload.classification)
    assert_equal(val, child.description.reload.classification)

    # Make sure have to be logged in. (update_column should avoid callbacks)
    new_val = names(:peltigera).classification
    # disable cop because we're trying to avoid callbacks
    # rubocop:disable Rails/SkipsModelValidations
    genus.update_columns(classification: new_val)
    # rubocop:enable Rails/SkipsModelValidations
    logout
    get(:propagate_classification, id: genus.id)
    assert_equal(val, child.reload.classification)

    # Now finally do it right and make sure it makes correct changes.
    login("rolf")
    get(:propagate_classification, id: genus.id)
    assert_equal(new_val, child.reload.classification)
    assert_equal(new_val, child.description.reload.classification)
  end

  def test_get_inherit_classification
    name = names(:boletus)

    # Make sure user has to be logged in.
    get(:inherit_classification, id: name.id)
    assert_redirected_to(controller: :account, action: :login)
    login("rolf")

    # Make sure it doesn't crash if id is missing.
    get(:inherit_classification)
    assert_flash_error
    assert_response(:redirect)

    # Make sure it doesn't crash if id is bogus.
    get(:inherit_classification, id: "bogus")
    assert_flash_error
    assert_response(:redirect)

    # Make sure it doesn't crash if id is bogus.
    get_with_dump(:inherit_classification, id: name.id)
    assert_no_flash
    assert_response(:success)
    assert_template("inherit_classification")
  end

  def test_post_inherit_classification
    name = names(:boletus)

    # Make sure user has to be logged in.
    post(:inherit_classification, id: name, parent: "Agaricales")
    assert_redirected_to(controller: :account, action: :login)
    login("rolf")

    # Make sure it doesn't crash if id is missing.
    post(:inherit_classification, parent: "Agaricales")
    assert_flash_error
    assert_response(:redirect)

    # Make sure it doesn't crash if id is bogus.
    post(:inherit_classification, id: "bogus", parent: "Agaricales")
    assert_flash_error
    assert_response(:redirect)

    # Test reload if parent field missing.
    post(:inherit_classification, id: name.id, parent: "")
    assert_flash_error
    assert_response(:success)
    assert_template(:inherit_classification)

    # Test reload if parent field has no match and no alternate spellings.
    post(:inherit_classification, id: name.id, parent: "cakjdncaksdbcsdkn")
    assert_flash_error
    assert_response(:success)
    assert_template(:inherit_classification)
    assert_input_value("parent", "cakjdncaksdbcsdkn")

    # Test reload if parent field misspelled.
    post(:inherit_classification, id: name.id, parent: "Agariclaes")
    assert_no_flash
    assert_response(:success)
    assert_template(:inherit_classification)
    assert_not_blank(assigns(:message))
    assert_not_empty(assigns(:options))
    assert_select("span", text: "Agaricales")
    assert_input_value("parent", "Agariclaes")

    # Test ambiguity: three names all accepted and with classifications.
    parent1 = names(:agaricaceae)
    parent1.change_author("Ach.")
    parent1.save
    parent2 = create_name("Agaricaceae Bagl.")
    parent2.classification = "Domain: _Eukarya_"
    parent2.save
    parent3 = create_name("Agaricaceae Clauzade")
    parent3.classification = "Domain: _Eukarya_"
    parent3.save
    post(:inherit_classification, id: name.id, parent: "Agaricaceae")
    assert_no_flash
    assert_response(:success)
    assert_template(:inherit_classification)
    assert_not_blank(assigns(:message))
    assert_not_empty(assigns(:options))
    assert_select("input[type=radio][value='#{parent1.id}']", count: 1)
    assert_select("input[type=radio][value='#{parent2.id}']", count: 1)
    assert_select("input[type=radio][value='#{parent3.id}']", count: 1)
    assert_input_value("parent", "Agaricaceae")

    # Have it select a bogus name (rank wrong in this case).
    post(:inherit_classification,
         id: name.id,
         parent: "Agaricaceae",
         options: names(:coprinus_comatus).id)
    assert_flash_error
    assert_response(:success)
    assert_template(:inherit_classification)

    # Make it less ambiguous, so it will select the original Agaricaceae.
    Name.update(parent2.id, classification: "")
    Name.update(parent3.id, deprecated: true)
    assert_blank(name.reload.classification)
    post(:inherit_classification, id: name.id, parent: "Agaricaceae")
    assert_no_flash
    assert_name_list_equal([], assigns(:options))
    assert_blank(assigns(:message))
    assert_redirected_to(name.show_link_args)
    new_str = "#{parent1.classification}\r\nFamily: _Agaricaceae_\r\n"
    assert_equal(new_str, name.reload.classification)
    assert_equal(new_str, names(:boletus_edulis).classification)
    assert_equal(new_str, observations(:boletus_edulis_obs).classification)
  end

  def test_get_edit_classification
    # Make sure user has to be logged in.
    get(:edit_classification)
    assert_redirected_to(controller: :account, action: :login)
    login("rolf")

    # Make sure missing and bogus ids do not crash it.
    get(:edit_classification)
    assert_response(:redirect)
    get(:edit_classification, id: "bogus")
    assert_response(:redirect)

    # Make sure form initialized correctly.
    name = names(:boletus_edulis)
    get(:edit_classification, id: name.id)
    assert_response(:success)
    assert_template(:edit_classification)
    assert_textarea_value(:classification, "")

    name = names(:agaricus_campestris)
    get_with_dump(:edit_classification, id: name.id)
    assert_response(:success)
    assert_template(:edit_classification)
    assert_textarea_value(:classification, name.classification)
  end

  def test_post_edit_classification
    # Make sure user has to be logged in.
    post(:edit_classification)
    assert_redirected_to(controller: :account, action: :login)
    login("rolf")

    # Make sure bogus requests don't crash.
    post(:edit_classification)
    assert_flash_error
    assert_response(:redirect)
    post(:edit_classification, id: "bogus")
    assert_flash_error
    assert_response(:redirect)

    # Make sure it is validating the classification.
    name = names(:agaricus_campestris)
    post(:edit_classification, id: name.id, classification: "bogus")
    assert_flash_error
    assert_response(:success)
    assert_template(:edit_classification)
    assert_textarea_value(:classification, "bogus")

    # Make sure we can do simple case.
    name = names(:agaricales)
    new_str = "Kingdom: _Fungi_"
    post(:edit_classification, id: name.id, classification: new_str)
    assert_no_flash
    assert_redirected_to(name.show_link_args)
    assert_equal(new_str, name.reload.classification)

    # Make sure we can do complex case.
    name = names(:agaricus_campestris)
    new_str = "Kingdom: _Fungi_\r\nPhylum: _Ascomycota_"
    post(:edit_classification, id: name.id, classification: new_str)
    assert_no_flash
    assert_redirected_to(name.show_link_args)
    assert_equal(new_str, name.reload.classification)
    assert_equal(new_str, names(:agaricus).classification)
    assert_equal(new_str,
                 names(:agaricus_campestras).description.classification)
    assert_equal(new_str, observations(:agaricus_campestras_obs).classification)
  end

  # -----------------------
  #  Test lifeform stuff.
  # -----------------------

  def test_edit_lifeform
    # Prove that anyone logged in can edit lifeform, and that the form starts
    # off with the correct current state.
    name = names(:peltigera)
    assert_equal(" lichen ", name.lifeform)
    requires_login(:edit_lifeform, id: name.id)
    assert_template(:edit_lifeform)
    Name.all_lifeforms.each do |word|
      assert_input_value("lifeform_#{word}", word == "lichen" ? "1" : "")
    end

    # Make sure user can both add and remove lifeform categories.
    params = { id: name.id }
    Name.all_lifeforms.each do |word|
      params["lifeform_#{word}"] = (word == "lichenicolous" ? "1" : "")
    end
    post(:edit_lifeform, params)
    assert_equal(" lichenicolous ", name.reload.lifeform)
  end

  def test_propagate_lifeform
    name = names(:lecanorales)
    children = name.all_children
    Name.update(name.id, lifeform: " lichen ")

    # Prove that getting to the form requires a login, and that it starts off
    # with all boxes unchecked.
    requires_login(:propagate_lifeform, id: name.id)
    assert_template(:propagate_lifeform)
    Name.all_lifeforms.each do |word|
      if word == "lichen"
        assert_input_value("add_#{word}", "")
      else
        assert_input_value("remove_#{word}", "")
      end
    end

    # Make sure we can add "lichen" to all children.
    post(:propagate_lifeform, id: name.id, add_lichen: "1")
    assert_redirected_to(name.show_link_args)
    children.each do |child|
      assert(child.reload.lifeform.include?(" lichen "),
             "Child, #{child.search_name}, is missing 'lichen'.")
    end

    # Make sure we can remove "lichen" from all children, too.
    post(:propagate_lifeform, id: name.id, remove_lichen: "1")
    assert_redirected_to(name.show_link_args)
    children.each do |child|
      assert_not(child.reload.lifeform.include?(" lichen "),
                 "Child, #{child.search_name}, still has 'lichen'.")
    end
  end

  def test_why_danny_cant_edit_lentinus_description
    desc = name_descriptions(:boletus_edulis_desc)
    get(:show_name_description, id: desc.id)
    assert_no_flash
    assert_template(:show_name_description)
  end

  def test_group_name_of_one_user_group
    assert_equal(:adjust_permissions_all_users.t,
                 @controller.group_name(user_groups(:all_users)))
    assert_equal(:REVIEWERS.t,
                 @controller.group_name(user_groups(:reviewers)))
    assert_equal(rolf.legal_name,
                 @controller.group_name(user_groups(:rolf_only)))
    assert_equal("article writers",
                 @controller.group_name(user_groups(:article_writers)))
  end
end
