# frozen_string_literal: true

require("test_helper")

module SpeciesLists
  class DownloadsControllerTest < FunctionalTestCase
    def test_make_report
      login
      now = Time.zone.now

      User.current = rolf
      tapinella = Name.create(
        author: "(Batsch) Šutara",
        text_name: "Tapinella atrotomentosa",
        search_name: "Tapinella atrotomentosa (Batsch) Šutara",
        sort_name: "Tapinella atrotomentosa (Batsch) Šutara",
        display_name: "**__Tapinella atrotomentosa__** (Batsch) Šutara",
        deprecated: false,
        rank: "Species"
      )

      list = species_lists(:first_species_list)
      args = {
        place_name: "limbo",
        when: now,
        created_at: now,
        updated_at: now,
        user: rolf,
        specimen: false
      }
      list.construct_observation(tapinella, args)
      list.construct_observation(names(:fungi), args)
      list.construct_observation(names(:coprinus_comatus), args)
      list.construct_observation(names(:lactarius_alpigenes), args)
      list.save # just in case

      path = Rails.root.join("test/reports")

      post(:create, params: { id: list.id, type: "csv" })
      assert_response_equal_file(["#{path}/test.csv", "ISO-8859-1"])

      post(:create, params: { id: list.id, type: "txt" })
      assert_response_equal_file("#{path}/test.txt")

      post(:create, params: { id: list.id, type: "rtf" })
      assert_response_equal_file("#{path}/test.rtf") do |x|
        x.sub(/\{\\createim\\yr.*\}/, "")
      end

      post(:create, params: { id: list.id, type: "bogus" })
      assert_response(:redirect)
      assert_flash_error
    end

    def test_print_labels
      login
      spl = species_lists(:one_genus_three_species_list)
      query = Query.lookup_and_save(:Observation, :in_species_list,
                                    species_list: spl)
      query_params = @controller.query_params(query)
      get(:print_labels, params: { id: spl.id })
      assert_redirected_to(
        print_labels_for_observations_path(params: query_params)
      )
    end

    def test_download
      login
      spl = species_lists(:one_genus_three_species_list)
      query = Query.lookup_and_save(:Observation, :in_species_list,
                                    species_list: spl)
      query_params = @controller.query_params(query)
      get(:new, params: { id: spl.id })
      url = print_labels_for_observations_path(params: query_params)
      assert_select("form[action='#{url}']")

      url = species_list_downloads_path(spl.id, params: query_params)
      assert_select("form[action='#{url}']")

      url = observations_downloads_path(params: query_params)
      assert_select("form[action='#{url}']")
    end
  end
end
