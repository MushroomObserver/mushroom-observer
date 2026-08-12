# frozen_string_literal: true

require("test_helper")

module SpeciesLists
  class DownloadsControllerTest < FunctionalTestCase
    def test_make_report
      login
      now = Time.zone.now

      tapinella = Name.create(
        author: "(Batsch) Šutara",
        text_name: "Tapinella atrotomentosa",
        search_name: "Tapinella atrotomentosa (Batsch) Šutara",
        sort_name: "Tapinella atrotomentosa (Batsch) Šutara",
        display_name: "**__Tapinella atrotomentosa__** (Batsch) Šutara",
        deprecated: false,
        rank: "Species",
        user: rolf
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

      post(:create,
           params: { id: list.id, species_list_report: { format: "csv" } })
      assert_response_equal_file(["#{path}/test.csv", "ISO-8859-1"])

      post(:create,
           params: { id: list.id, species_list_report: { format: "txt" } })
      assert_response_equal_file("#{path}/test.txt")

      post(:create,
           params: { id: list.id, species_list_report: { format: "rtf" } })
      assert_response_equal_file("#{path}/test.rtf") do |x|
        x.sub(/\{\\createim\\yr.*\}/, "")
      end

      # Regression: an invalid format falls back to the default ("txt")
      # instead of erroring out.
      post(:create,
           params: { id: list.id, species_list_report: { format: "bogus" } })
      assert_response_equal_file("#{path}/test.txt")
    end

    def test_print_labels
      login
      spl = species_lists(:one_genus_three_species_list)
      query = Query.lookup_and_save(:Observation, species_lists: spl)
      params = { q: @controller.q_param(query) }
      get(:print_labels, params: { id: spl.id })
      assert_redirected_to(
        print_labels_for_observations_path(params:)
      )
    end

    def test_download
      login
      spl = species_lists(:one_genus_three_species_list)
      query = Query.lookup_and_save(:Observation, species_lists: spl)
      params = { q: @controller.q_param(query) }
      get(:new, params: { id: spl.id })
      url = print_labels_for_observations_path(params:)
      assert_select("form[action='#{url}']")

      url = download_species_list_path(spl.id, params:)
      assert_select("form[action='#{url}']")

      url = observations_downloads_path(params:)
      assert_select("form[action='#{url}']")
    end

    # Regression: `format`/`encoding`/`species_list_report[format]` come
    # straight from raw params with no upstream validation -- garbage
    # values must fall back to the default radio selection, not crash
    # or silently pre-select something invalid.
    def test_new_validates_invalid_format_and_encoding_params
      login
      spl = species_lists(:one_genus_three_species_list)

      get(:new, params: {
            id: spl.id,
            format: "bogus",
            encoding: "bogus",
            species_list_report: { format: "bogus" }
          })

      assert_response(:success)
      assert_select(
        "input[name='species_list_report[format]'][value='txt'][checked]"
      )
      assert_select("input[name='download[format]'][value='raw'][checked]")
      assert_select(
        "input[name='download[encoding]'][value='UTF-8'][checked]"
      )
    end
  end
end
