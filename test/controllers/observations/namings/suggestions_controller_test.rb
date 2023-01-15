# frozen_string_literal: true

require("test_helper")

module Observations::Namings
  class SuggestionsControllerTest < FunctionalTestCase
    def test_suggestions
      obs = observations(:detailed_unknown_obs)
      name1 = names(:coprinus_comatus)
      name2a = names(:lentinellus_ursinus_author1)
      name2b = names(:lentinellus_ursinus_author2)
      obs.name = name2b
      obs.vote_cache = 2.0
      obs.save
      assert_not_nil(obs.thumb_image)
      assert_obj_arrays_equal([], name2a.reload.observations)
      assert_obj_arrays_equal([obs], name2b.reload.observations)
      suggestions = '[[["Coprinus comatus",0.7654],' \
                      '["Lentinellus ursinus",0.321]]]'

      requires_login(:show, id: obs.id, names: suggestions)

      data = @controller.instance_variable_get(:@suggestions)
      assert_equal(2, data.length)
      data = data.sort_by(&:max).reverse
      assert_names_equal(name1, data[0].name)
      assert_names_equal(name2b, data[1].name)
      assert_equal(0.7654, data[0].max)
      assert_equal(0.321, data[1].max)
      assert_objs_equal(obs, data[1].image_obs)
    end
  end
end
