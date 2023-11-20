# frozen_string_literal: true

require("test_helper")

module Observations
  class DownloadsControllerTest < FunctionalTestCase
    def test_download_observation_index
      obs = Observation.where(user: mary)
      assert(obs.length >= 4)
      query = Query.lookup_and_save(:Observation, :by_user, user: mary.id)

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
          format: "darwin",
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
    end

    def test_print_labels
      login
      query = Query.lookup_and_save(:Observation, :by_user, user: mary.id)
      assert_operator(query.num_results, :>=, 4)
      get(:print_labels, params: { q: query.id.alphabetize })
      # \pard is paragraph command in rtf, one paragraph per result
      assert_equal(query.num_results, @response.body.scan("\\pard").size)
      assert_match(/314159/, @response.body) # make sure fundis id in there!
      assert_match(/Mary Newbie 174/, @response.body) # and collection number!

      # Alternative entry point.
      post(
        :create,
        params: {
          q: query.id.alphabetize,
          commit: "Print Labels"
        }
      )
      assert_equal(query.num_results, @response.body.scan("\\pard").size)
    end

    def test_project_labels
      login("roy")
      query = Query.lookup_and_save(:Observation, :for_project,
                                    project: projects(:open_membership_project))
      get(:print_labels, params: { q: query.id.alphabetize })
      trusted_hidden = observations(:trusted_hidden)
      untrusted_hidden = observations(:untrusted_hidden)
      assert_match(/#{trusted_hidden.lat}/, @response.body)
      assert_no_match(/#{untrusted_hidden.lat}/, @response.body)
    end

    # Print labels for all observations just to be sure all cases (more or less)
    # are tested and at least not crashing.
    def test_print_labels_all
      login
      query = Query.lookup_and_save(:Observation, :all)
      get(:print_labels, params: { q: query.id.alphabetize })
    end

    def test_print_labels_query_nil
      login
      query = Query.lookup_and_save(:Observation, :by_user, user: mary.id)

      # simulate passing a query param, but that query doesn't exist
      @controller.stub(:find_query, nil) do
        get(
          :print_labels,
          params: { q: query.id.alphabetize, commit: "Print Labels" }
        )
      end

      assert_flash_error
    end
  end
end
