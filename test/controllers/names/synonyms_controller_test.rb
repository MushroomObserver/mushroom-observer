# frozen_string_literal: true

require("test_helper")

module Names
  class SynonymsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_change_synonyms
      name = names(:chlorophyllum_rachodes)
      params = { id: name.id }
      requires_login(:edit, params)
      assert_form_action(action: :update, approved_synonyms: [], id: name.id)
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
        synonym_members: add_name.text_name,
        deprecate_all: "1"
      }
      put_requires_login(:update, params)
      assert_redirected_to(name_path(selected_name.id))

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
        synonym_members: add_name.text_name,
        deprecate_all: "0"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

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
        synonym_members: "Lepiota rachodes var. rachodes",
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_template("names/synonyms/edit")
      assert_template("names/synonyms/_fields_proposed")
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
        synonym_members: "Lepiota rachodes var. rachodes",
        approved_names: "Lepiota rachodes var. rachodes",
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

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
        synonym_members: [
          "Lepiota rachodes var. rachodes",
          "Lepiota rhacodes var. rhacodes"
        ].join("\r\n"),
        approved_names: [
          "Lepiota rachodes var. rachodes",
          "Lepiota rhacodes var. rhacodes"
        ].join("\r\n"),
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(page_name.id))

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
        synonym_members: add_name.search_name,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

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
      # Check all names not matching selected one
      selected_synonym.names.each do |n|
        next if n == selected_name

        assert_not(n.deprecated)
        split_name = n
        existing_synonyms[n.id.to_s] = "1"
      end
      assert_not_nil(split_name)

      params = {
        id: selected_name.id,
        synonym_members: add_name.search_name,
        existing_synonyms: existing_synonyms,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

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
        synonym_members: add_name.search_name,
        existing_synonyms: existing_synonyms,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

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
        synonym_members: add_name.search_name,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_template("names/synonyms/edit")
      assert_template("names/synonyms/_fields_proposed")

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
      start_count = add_synonym.names.count

      selected_name = names(:lepiota_rachodes)
      assert_not(selected_name.deprecated)
      selected_version = selected_name.version
      assert_nil(selected_name.synonym_id)

      synonym_ids = add_synonym.names.map(&:id).join("/")
      params = {
        id: selected_name.id,
        synonym_members: add_name.search_name,
        approved_synonyms: synonym_ids,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

      assert(add_name.reload.deprecated)
      assert_equal(add_version + 1, add_name.version)
      add_synonym = add_name.synonym
      assert_not_nil(add_synonym)

      assert_not(selected_name.reload.deprecated)
      assert_equal(selected_version, selected_name.version)
      selected_synonym = selected_name.synonym
      assert_not_nil(selected_synonym)
      assert_equal(add_synonym, selected_synonym)

      assert_equal(start_count + 1, add_synonym.names.count)
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
      start_count = add_synonym.names.count

      selected_name = names(:lepiota_rachodes)
      assert_not(selected_name.deprecated)
      selected_version = selected_name.version
      assert_nil(selected_name.synonym_id)

      synonym_names = add_synonym.names.map(&:search_name).join("\r\n")
      params = {
        id: selected_name.id,
        synonym_members: synonym_names,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

      assert(add_name.reload.deprecated)
      assert_equal(add_version + 1, add_name.version)
      add_synonym = add_name.synonym
      assert_not_nil(add_synonym)

      assert_not(selected_name.reload.deprecated)
      assert_equal(selected_version, selected_name.version)
      selected_synonym = selected_name.synonym
      assert_not_nil(selected_synonym)
      assert_equal(add_synonym, selected_synonym)

      assert_equal(start_count + 1, add_synonym.names.count)
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
        synonym_members: add_name.search_name,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_template("names/synonyms/edit")
      assert_template("names/synonyms/_fields_proposed")

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
        synonym_members: add_name.search_name,
        approved_synonyms: synonym_ids,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

      assert(add_name.reload.deprecated)
      assert_equal(add_version + 1, add_name.version)
      add_synonym = add_name.synonym
      assert_not_nil(add_synonym)
      assert_equal(add_start_size + selected_start_size,
                   add_synonym.names.size)

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
        synonym_members: synonym_names,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

      assert(add_name.reload.deprecated)
      assert_equal(add_version + 1, add_name.version)
      assert_not_nil(add_synonym = add_name.synonym)
      assert_equal(add_start_size + selected_start_size,
                   add_synonym.names.size)

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
      for n in selected_synonym.names # rubocop:disable Style/For
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
        synonym_members: "",
        existing_synonyms: existing_synonyms,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

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
        synonym_members: "",
        existing_synonyms: existing_synonyms,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

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
        synonym_members: "",
        existing_synonyms: existing_synonyms,
        deprecate_all: "1"
      }
      login("rolf")
      put(:update, params: params)
      assert_redirected_to(name_path(selected_name.id))

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
        synonym_members: "",
        existing_synonyms: existing_synonyms,
        deprecate_all: ""
      }

      login("rolf")
      get(:edit, params: { id: name.id })
      assert_response(:redirect)
      put(:update, params: params)
      assert_flash_error
      assert_not_nil(name.reload.synonym_id)

      make_admin("mary")
      get(:edit, params: { id: name.id })
      assert_response(:success)
      put(:update, params: params)
      assert_nil(name.reload.synonym_id)
    end
  end
end
