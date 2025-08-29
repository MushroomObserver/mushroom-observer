# frozen_string_literal: true

require("test_helper")

module Observations
  class DownloadsControllerTest < FunctionalTestCase
    def test_new
      query = Query.lookup_and_save(:Observation, by_users: mary.id)
      assert(query.num_results > 1, "Test needs query with multiple results")

      login(:rolf)
      get(:new, params: { q: query.id.alphabetize })

      assert_no_flash
      assert_response(:success)
      assert_select("input[type=radio][id=format_mycoportal]", false,
                    "Missing a MyCoPortal radio button")
      assert_select("input[type=radio][id=format_mycoportal_image_list]", false,
                    "Missing a MyCoPortal Images radio button")
    end

    def test_new_admin
      query = Query.lookup_and_save(:Observation, by_users: mary.id)
      assert(query.num_results > 1, "Test needs query with multiple results")

      login(:rolf)
      make_admin("rolf")
      get(:new, params: { q: query.id.alphabetize })

      assert_no_flash
      assert_response(:success)
      assert_select("input[type=radio][id=format_mycoportal]", true,
                    "Missing a MyCoPortal radio button")
      assert_select("input[type=radio][id=format_mycoportal_image_list]", true,
                    "Missing a MyCoPortal Images radio button")
    end

    def test_download_observation_index
      obs = Observation.reorder(id: :asc).where(user: mary)
      assert(obs.length >= 4)
      query = Query.lookup_and_save(:Observation, by_users: mary.id)

      # Add herbarium_record to fourth obs for testing purposes.
      login("mary")
      fourth = obs.fourth
      fourth.herbarium_records << HerbariumRecord.create!(
        herbarium: herbaria(:nybg_herbarium),
        user: mary,
        initial_det: fourth.name.text_name,
        accession_number: "Mary #1234"
      )

      get(:new, params: { q: query.id.alphabetize })
      assert_no_flash
      assert_response(:success)
      assert_match(%r{observations/downloads\?q=}, @response.body)

      post(
        :create,
        params: {
          q: query.id.alphabetize,
          format: :raw,
          encoding: "UTF-8",
          commit: "Cancel"
        }
      )
      assert_no_flash
      # assert_redirected_to(action: :index)
      assert_redirected_to(%r{/observations})

      post(
        :create,
        params: {
          q: query.id.alphabetize,
          format: :raw,
          encoding: "UTF-8",
          commit: "Download"
        }
      )
      rows = @response.body.split("\n")
      ids = rows.map { |s| s.sub(/,.*/, "") }
      expected = %w[observation_id] + obs.map { |o| o.id.to_s }
      last_expected_index = expected.length - 1

      assert_no_flash
      assert_response(:success)
      assert_equal(expected, ids[0..last_expected_index],
                   "Exported 1st column incorrect")
      last_row = rows[last_expected_index].chomp
      o = obs.last
      nm = o.name
      l = o.location
      country = l.name.split(", ")[-1]
      state =   l.name.split(", ")[-2]
      city =    l.name.split(", ")[-3]
      labels =  o.try(:herbarium_records).map(&:herbarium_label).join(", ")

      # Hard coded values below come from the actual
      # part of a test failure message.
      # If fixtures change, these may also need to be changed.
      assert_equal(
        "#{o.id},#{mary.id},mary,Mary Newbie,#{o.when}," \
        "X,\"#{labels}\"," \
        "#{nm.id},#{nm.text_name},#{nm.author},#{nm.rank},0.0," \
        "#{l.id},#{country},#{state},,#{city}," \
        ",,,34.22,34.15,-118.29,-118.37," \
        "#{l.high.to_f.round},#{l.low.to_f.round}," \
        "#{"X" if o.is_collection_location},#{o.thumb_image_id}," \
        "#{o.notes[Observation.other_notes_key]}," \
        "#{MO.http_domain}/#{o.id}",
        last_row.iconv("utf-8"),
        "Exported last row incorrect"
      )

      post(
        :create,
        params: {
          q: query.id.alphabetize,
          format: "raw",
          encoding: "ASCII",
          commit: "Download"
        }
      )
      assert_no_flash
      assert_response(:success)

      post(
        :create,
        params: {
          q: query.id.alphabetize,
          format: "raw",
          encoding: "UTF-16",
          commit: "Download"
        }
      )
      assert_no_flash
      assert_response(:success)

      post(
        :create,
        params: {
          q: query.id.alphabetize,
          format: "adolf",
          encoding: "UTF-8",
          commit: "Download"
        }
      )
      assert_no_flash
      assert_response(:success)

      post(
        :create,
        params: {
          q: query.id.alphabetize,
          format: "dwca",
          encoding: "UTF-8",
          commit: "Download"
        }
      )
      assert_no_flash
      assert_response(:success)

      post(
        :create,
        params: {
          q: query.id.alphabetize,
          format: "symbiota",
          encoding: "UTF-8",
          commit: "Download"
        }
      )
      assert_no_flash
      assert_response(:success)

      post(
        :create,
        params: {
          q: query.id.alphabetize,
          format: "fundis",
          encoding: "UTF-8",
          commit: "Download"
        }
      )
      assert_no_flash
      assert_response(:success)

      post(
        :create,
        params: {
          q: query.id.alphabetize,
          format: "mycoportal",
          encoding: "UTF-8",
          commit: "Download"
        }
      )
      assert_no_flash
      assert_response(:success)

      format = "nonexistent"
      assert_raises("Invalid download type: #{format}") do
        post(:create,
             params: {
               q: query.id.alphabetize,
               format: format,
               commit: "Download"
             })
      end
    end

    def test_download_too_many_observations
      query = Query.lookup_and_save(:Observation)
      login("mary")

      MO.stub(:max_downloads, Observation.count - 1) do
        get(:new, params: { q: query.id.alphabetize })
      end

      assert_redirected_to(observations_path)
      assert_flash_error
    end

    def test_download_too_many_observations_reasonable_query
      query = Query.lookup_and_save(:Observation, locations: locations(:albion))
      login("mary")

      MO.stub(:max_downloads, Observation.count - 1) do
        get(:new, params: { q: query.id.alphabetize })
      end

      assert_response(:success)
    end

    def test_download_too_many_observations_admin
      query = Query.lookup_and_save(:Observation)
      login("mary")
      make_admin("mary")

      MO.stub(:max_downloads, Observation.count - 1) do
        get(:new, params: { q: query.id.alphabetize })
      end

      assert_response(:success)
    end

    def test_print_labels
      login
      query = Query.lookup_and_save(:Observation, by_users: mary.id)
      assert_operator(query.num_results, :>=, 4)
      get(:print_labels, params: { q: query.id.alphabetize })
      assert_pdf(@response)

      # Alternative entry point.
      post(
        :create,
        params: {
          q: query.id.alphabetize,
          commit: "Print Labels"
        }
      )
      assert_pdf(@response)
    end

    def assert_pdf(response)
      assert_equal("application/pdf", response.content_type)
      pdf_content = response.body.force_encoding("ASCII-8BIT")
      assert(pdf_content.start_with?("%PDF-"), "Should generate valid PDF")
      assert(pdf_content.include?("%%EOF"), "Should have valid PDF ending")
    end

    def test_project_labels
      login("roy")
      query = Query.lookup_and_save(
        :Observation, projects: projects(:open_membership_project)
      )
      get(:print_labels, params: { q: query.id.alphabetize })
      assert_pdf(@response)
    end

    # Print labels for all observations just to be sure all cases (more or less)
    # are tested and at least not crashing.
    def test_print_labels_all
      login
      query = Query.lookup_and_save(:Observation)
      get(:print_labels, params: { q: query.id.alphabetize })
    end

    def test_print_labels_query_nil
      login
      query = Query.lookup_and_save(:Observation, by_users: mary.id)

      # simulate passing a query param, but that query doesn't exist
      @controller.stub(:find_query, nil) do
        get(
          :print_labels,
          params: { q: query.id.alphabetize, commit: "Print Labels" }
        )
      end

      assert_flash_error
    end

    def test_mycoportal_image_list
      query = Query.lookup_and_save(:Observation, by_users: [dick])
      obss_with_images =
        Observation.joins(:images).where(id: query.results(&:id)).
        order(id: :asc, image_id: :asc)
      assert(obss_with_images.many?,
             "Test needs query which results in many Observations with Images")
      assert(
        obss_with_images.any? { |obs| obs.images.many? },
        "Test needs query which results in >=1 Observations with many Images"
      )
      expect = ["catalogNumber,imageId"]
      obss_with_images.uniq.each do |obs|
        obs.images.each do |image|
          expect << "MUOB #{obs.id}," \
                    "https://mushroomobserver.org/images/1280/#{image.id}.jpg"
        end
      end

      login
      post(:create, params: { q: query.id.alphabetize,
                              format: :mycoportal_image_list,
                              encoding: "UTF-8",
                              commit: "Download" })

      assert_response(:success)
      rows = @response.body.split("\n")
      assert_equal("catalogNumber,imageId", rows.first, "Wrong header row")
      assert_equal(obss_with_images.count + 1, rows.count)
      assert_equal(expect, rows, "Wrong MyCoPortal Image List csv")
    end
  end
end
