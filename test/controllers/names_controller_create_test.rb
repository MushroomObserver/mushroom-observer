# frozen_string_literal: true

require("test_helper")

class NamesControllerCreateTest < FunctionalTestCase
  tests NamesController
  include ObjectLinkHelper

  def setup
    @new_pts  = 10
    @chg_pts  = 10
    @auth_pts = 100
    @edit_pts = 10
    @@emails = []
    super
  end

  def assert_no_emails
    msg = @@emails.join("\n")
    assert(@@emails.empty?,
           "Wasn't expecting any email notifications; got:\n#{msg}")
  ensure
    @@emails = []
  end

  # ----------------------------
  #  Create name.
  # ----------------------------

  def test_new_name
    requires_login(:new)

    assert_form_action(action: :create)
    assert_select("select#name_rank") do
      assert_select("option[selected]", text: "Species")
    end
    assert_select("select#name_deprecated") do
      assert_select("option[selected]", text: :ACCEPTED.l)
    end
    assert_select("form #name_icn_id", { count: 1 },
                  "Form is missing field for icn_id")
  end

  def test_create_name_post
    text_name = "Amanita velosa"
    assert_not(Name.find_by(text_name: text_name))
    author = "(Peck) Lloyd"
    icn_id = 485_288
    params = {
      name: {
        icn_id: icn_id,
        text_name: text_name,
        author: author,
        rank: "Species",
        citation: "??Mycol. Writ.?? 9(15). 1898."
      }
    }
    post_requires_login(:create, params)

    assert(name = Name.find_by(text_name: text_name))
    assert_redirected_to(name_path(name.id))
    assert_equal(10 + @new_pts, rolf.reload.contribution)
    assert_equal(icn_id, name.icn_id)
    assert_equal(author, name.author)
    assert_equal(rolf, name.user)
  end

  def test_create_name_blank
    login(rolf.login)
    params = {
      name: {
        text_name: "",
        author: "",
        rank: "Species",
        citation: ""
      }
    }
    # Just make sure it doesn't crash!
    post(:create, params: params)
  end

  def test_create_name_existing
    name = names(:conocybe_filaris)
    text_name = name.text_name
    count = Name.count
    params = {
      name: {
        text_name: text_name,
        author: "",
        rank: "Species",
        citation: ""
      }
    }
    login(rolf.login)
    post(:create, params: params)

    assert_response(:success)
    last_name = Name.last
    assert_equal(count, Name.count,
                 "Shouldn't have created #{last_name.search_name.inspect}.")
    names = Name.where(text_name: text_name)
    assert_obj_arrays_equal([names(:conocybe_filaris)], names)
    assert_equal(10, rolf.reload.contribution)
  end

  def test_create_name_icn_already_used
    old_name = names(:coprinus_comatus)
    assert_true(old_name.icn_id.present?)
    name_count = Name.count
    rss_log_count = RssLog.count
    params = {
      name: {
        icn_id: old_name.icn_id.to_s,
        text_name: "Something else",
        author: "(Thank You) Why Not",
        rank: "Species",
        citation: "I'll pass"
      }
    }
    login(mary.login)
    post(:create, params: params)
    assert_response(:success)
    last_name = Name.last
    assert_equal(name_count, Name.count,
                 "Shouldn't have created #{last_name.search_name.inspect}.")
    assert_equal(rss_log_count, RssLog.count,
                 "Shouldn't have created an RSS log! " \
                 "#{RssLog.last.inspect}.")
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
    login(rolf.login)
    post(:create, params: params)

    assert_flash_text(flash_text)
    assert_response(:success)
    last_name = Name.last
    assert_equal(count, Name.count,
                 "Shouldn't have created #{last_name.search_name.inspect}.")
  end

  def test_create_name_unauthored_authored
    # Prove user can't create authored non-"Group" Name
    # if unauthored one exists.
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
    post(:create, params: params)

    assert_response(:success)
    flash_text = :runtime_name_create_already_exists.t(
      name: name.user_display_name
    )
    assert_flash_text(flash_text)
    assert_empty(name.reload.author)
    assert_equal(old_name_count, Name.count)
    expect = user.contribution
    assert_equal(expect, user.reload.contribution)

    # And vice versa. Prove user can't create unauthored non-"Group" Name
    # if authored one exists.
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
    post(:create, params: params)

    assert_response(:success)
    flash_text = :runtime_name_create_already_exists.t(
      name: name.user_display_name
    )
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
        rank: "Group",
        citation: ""
      }
    }
    login(rolf.login)
    old_contribution = rolf.contribution
    post(:create, params: params)

    assert(authored_name = Name.find_by(search_name: "#{text_name} Author"))
    assert_flash_success
    assert_redirected_to(name_path(authored_name.id))
    assert(Name.exists?(name.id))
    assert_equal(old_contribution + UserStats::ALL_FIELDS[:names][:weight],
                 rolf.reload.contribution)
  end

  def test_create_name_bad_name
    text_name = "Amanita Pantherina"
    name = Name.find_by(text_name: text_name)
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        rank: "Species"
      }
    }
    login(rolf.login)
    post(:create, params: params)
    assert_template("names/new")
    assert_select("#name_form")
    # Should fail and no name should get created
    assert_nil(Name.find_by(text_name: text_name))
    assert_form_action(action: :create)
  end

  def test_create_name_author_trailing_comma
    text_name = "Inocybe magnifolia"
    name = Name.find_by(text_name: text_name)
    punct = "!"
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        author: "Matheny, Aime & T.W. Henkel,",
        rank: :Species
      }
    }
    login(rolf.login)

    assert_no_difference(
      "Name.count",
      "A Name should not be created when Author ends with #{punct}"
    ) do
      post(:create, params: params)
    end
    assert_flash_error(:name_error_field_end.l)
  end

  def test_create_name_citation_leading_commma
    text_name = "Coprinopsis nivea"
    name = Name.find_by(text_name: text_name)
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        author: "(Pers.) Redhead, Vilgalys & Moncalvo",
        citation: ", in Redhead, Taxon 50(1): 229 (2001)",
        rank: :Species
      }
    }
    login(rolf.login)

    assert_no_difference(
      "Name.count",
      "A Name should not be created when Citation starts with ','"
    ) do
      post(:create, params: params)
    end
    assert_flash_error(:name_error_field_start.l)
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
        rank: "Genus"
      }
    }
    post_requires_login(:create, params)

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
        rank: "Phylum"
      }
    }
    login(rolf.login)
    post(:create, params: params)
    # Now try to find it
    assert(name = Name.find_by(text_name: text_name))
    assert_redirected_to(name_path(name.id))
  end

  def test_create_name_with_many_implicit_creates
    text_name = "Some thing ssp. with v. many forma names"
    text_name2 = "Some thing subsp. with var. many f. names"
    name = Name.find_by(text_name: text_name)
    count = Name.count
    assert_nil(name)
    params = {
      name: {
        text_name: text_name,
        rank: "Form"
      }
    }
    login(rolf.login)
    post(:create, params: params)
    # Now try to find it
    assert(name = Name.find_by(text_name: text_name2))
    assert_redirected_to(name_path(name.id))
    assert_equal(count + 5, Name.count)
  end

  def test_create_species_under_ambiguous_genus
    login(dick.login)
    agaricus1 = names(:agaricus)
    agaricus1.change_author("L.")
    agaricus1.skip_notify = true
    agaricus1.save
    Name.create!(
      text_name: "Agaricus",
      search_name: "Agaricus Raf.",
      sort_name: "Agaricus Raf.",
      display_name: "**__Agaricus__** Raf.",
      author: "Raf.",
      rank: "Genus",
      deprecated: false,
      correct_spelling: nil,
      user: dick
    )
    agarici = Name.where(text_name: "Agaricus")
    assert_equal(2, agarici.length)
    assert_equal("L.", agarici.first.author)
    assert_equal("Raf.", agarici.last.author)
    params = {
      name: {
        text_name: "Agaricus endoxanthus",
        author: "",
        rank: "Species",
        citation: "",
        deprecated: "false"
      }
    }
    post(:create, params: params)
    assert_flash_success
    assert_redirected_to(name_path(Name.last.id))
  end

  def test_create_family
    login(dick.login)
    params = {
      name: {
        text_name: "Lecideaceae",
        author: "",
        rank: "Genus",
        citation: "",
        deprecated: "false"
      }
    }
    post(:create, params: params)
    assert_flash_error
    params[:name][:rank] = "Family"
    post(:create, params: params)
    assert_flash_success
  end

  def test_create_variety
    text_name = "Pleurotus djamor var. djamor"
    author    = "(Fr.) Boedijn"
    params = {
      name: {
        text_name: "#{text_name} #{author}",
        author: "",
        rank: "Variety",
        deprecated: "false"
      }
    }
    login(katrina.login)
    post(:create, params: params)

    assert(name = Name.find_by(text_name: text_name))
    assert_flash_success
    assert_redirected_to(name_path(name.id))
    assert_no_emails
    assert_equal("Variety", name.rank)
    assert_equal("#{text_name} #{author}", name.search_name)
    assert_equal(author, name.author)
    assert(Name.find_by(text_name: "Pleurotus djamor"))
    assert(Name.find_by(text_name: "Pleurotus"))
  end

  def test_create_prov_sp_quoted_epithet_with_space
    # Based onhttps://www.inaturalist.org/observations/137770340
    user = users(:rolf)
    text_name = 'Hygrocybe "constrictospora PNW08"'
    params = {
      user: user,
      name: {
        text_name: text_name,
        author: "",
        rank: "Species",
        deprecated: "false"
      }
    }

    login(user.login)
    assert_difference("Name.count", 1, "Failed to create Name") do
      post(:create, params: params)
    end

    assert_response(:redirect)
    name = Name.find_by(text_name: "Hygrocybe sp. 'constrictospora-PNW08'")
    assert(name)
    assert_equal("Species", name.rank)
    assert_equal("Hygrocybe sp. 'constrictospora-PNW08'", name.search_name)
    assert_equal("**__Hygrocybe__** sp. **__'constrictospora-PNW08'__**",
                 name.user_display_name)
    assert_equal("Hygrocybe constrictospora-pnw08", name.sort_name)
  end

  def test_create_prov_sp_capitalized_unquoted_undashed_epithet
    # Based on https://www.inaturalist.org/observations/212320801
    user = users(:rolf)
    text_name = "Donadinia PNW01"
    params = {
      user: user,
      name: {
        text_name: text_name,
        author: "",
        rank: "Species",
        deprecated: "false"
      }
    }

    login(user.login)
    assert_difference("Name.count", 2, "Failed to create Name") do
      post(:create, params: params)
    end

    assert_response(:redirect)
    name = Name.find_by(text_name: "Donadinia sp. 'PNW01'")
    assert(name)
    assert_equal("Species", name.rank)
    assert_equal("Donadinia sp. 'PNW01'", name.search_name)
    assert_equal("**__Donadinia__** sp. **__'PNW01'__**",
                 name.user_display_name)
    assert_equal("Donadinia pnw01", name.sort_name)
  end

  def test_create_prov_genus_numerical
    # https://www.inaturalist.org/observations/143452821
    # NOTE jdc2025-03-30
    # This is a guess about what the result should be.
    # YMMV
    user = users(:rolf)
    text_name = "Hemimycena3"
    params = {
      user: user,
      name: {
        text_name: text_name,
        author: "",
        rank: "Genus",
        deprecated: "false"
      }
    }

    login(user.login)
    assert_difference("Name.count", 1, "Failed to create Name") do
      post(:create, params: params)
    end

    assert_response(:redirect)
    name = Name.order(id: :desc).first
    assert_equal("Genus", name.rank)
    assert_equal("Gen. 'Hemimycena3'", name.text_name)
    assert_equal("Gen. 'Hemimycena3'", name.search_name)
    assert_equal("Gen. **__'Hemimycena3'__**", name.user_display_name)
    assert_equal("Hemimycena3", name.sort_name)
  end
end
