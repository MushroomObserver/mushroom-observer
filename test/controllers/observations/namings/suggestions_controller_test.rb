# frozen_string_literal: true

require("test_helper")

module Observations::Namings
  class SuggestionsControllerTest < FunctionalTestCase
    def test_suggestions
      obs = observations(:detailed_unknown_obs)
      name1 = names(:coprinus_comatus)
      name2a = names(:dup_name_author1)
      name2b = names(:dup_name_author2)
      obs.name = name2b
      obs.vote_cache = 2.0
      obs.save
      assert_not_nil(obs.thumb_image)
      assert_obj_arrays_equal([], name2a.reload.observations)
      assert_obj_arrays_equal([obs], name2b.reload.observations)
      suggestions = '[[["Coprinus comatus",0.7654],' \
                      '["Agrocybe arvalis",0.321]]]'

      requires_login(:show, id: obs.id, names: suggestions)

      data = @controller.instance_variable_get(:@suggestions)
      assert_equal(2, data.length)
      data = data.sort_by(&:max).reverse
      assert_names_equal(name1, data[0].name)
      assert_names_equal(name2b, data[1].name)
      assert_in_delta(0.7654, data[0].max)
      assert_in_delta(0.321, data[1].max)
      assert_objs_equal(obs, data[1].image_obs)
    end

    # This endpoint's `names` param is always JS-supplied JSON from the
    # image classifier (see observations/show/namings/footer_buttons.rb)
    # -- a direct or stale request with no/bad JSON must redirect
    # instead of raising JSON::ParserError.
    def test_suggestions_blank_names_redirects
      obs = observations(:detailed_unknown_obs)

      login
      get(:show, params: { id: obs.id })

      assert_redirected_to(permanent_observation_path(obs.id))
    end

    def test_suggestions_malformed_names_redirects
      obs = observations(:detailed_unknown_obs)

      login
      get(:show, params: { id: obs.id, names: "not json" })

      assert_redirected_to(permanent_observation_path(obs.id))
    end

    # Valid JSON that isn't an Array -- Suggestion.analyze needs an
    # Array, so these must redirect too, not reach #each and crash.
    def test_suggestions_non_array_names_redirects
      obs = observations(:detailed_unknown_obs)
      login

      ["null", "{}", "false", "0", '"a string"'].each do |names|
        get(:show, params: { id: obs.id, names: names })

        assert_redirected_to(permanent_observation_path(obs.id),
                             "names=#{names} should redirect")
      end
    end
  end
end
