# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::ExternalLinksTest < UnitTestCase
  include API2Extensions

  def test_basic_external_link_get
    do_basic_get_test(ExternalLink)
  end

  # ----------------------------------
  #  :section: ExternalLink Requests
  # ----------------------------------

  def api2_model = ExternalLink

  def test_getting_external_links
    other_obs = observations(:agaricus_campestris_obs)
    link1 = external_links(:coprinus_comatus_obs_mycoportal_link)
    link2 = external_links(:coprinus_comatus_obs_inaturalist_link)
    link3 = ExternalLink.create!(user: rolf, observation: other_obs,
                                 external_site: link1.external_site,
                                 external_id: "876876")
    params = params_get

    assert_api_pass(params.merge(id: link2.id))
    assert_api_results([link2])

    assert_api_pass(params.merge(created_at: "2016-12-29"))
    assert_api_results([link1])

    assert_api_pass(params.merge(updated_at: "2016-11-11-2017-11-11"))
    assert_api_results([link1, link2])

    assert_api_pass(params.merge(user: "rolf"))
    assert_api_results([link3])

    assert_api_pass(params.merge(observation: other_obs.id))
    assert_api_results([link3])
    assert_api_pass(params.merge(observation: link1.observation.id))
    assert_api_results([link1, link2])

    assert_api_pass(params.merge(external_site: "mycoportal"))
    assert_api_results([link1, link3])
  end

  def test_posting_external_links
    marys_obs = observations(:detailed_unknown_obs)
    rolfs_obs = observations(:agaricus_campestris_obs)
    katys_obs = observations(:amateur_obs)
    marys_key = api_keys(:marys_api_key)
    rolfs_key = api_keys(:rolfs_api_key)
    site = external_sites(:mycoportal)
    url = site.observation_url("112233")
    params = params_post(api_key: rolfs_key.key, observation: rolfs_obs.id,
                         external_site: site.id, url: url)
    assert_api_pass(params)
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:observation))
    assert_api_fail(params.except(:external_site))
    assert_api_fail(params.except(:url))
    assert_api_fail(params.merge(api_key: "spammer"))
    assert_api_fail(params.merge(observation: "spammer"))
    assert_api_fail(params.merge(external_site: "spammer"))
    # Not url-shaped -- the API's `url` param requires a url, not a bare id.
    assert_api_fail(params.merge(url: "spammer"))
    assert_api_fail(params.merge(observation: marys_obs.id))
    # The model allows multiple links per (obs, site), but the API rejects an
    # exact duplicate (same obs/site/external_id) (#4565). mary is permitted
    # via her mycoportal membership, so this fails on duplication, not
    # permission.
    assert_api_fail(params.merge(api_key: marys_key.key))
    assert_api_pass(params.merge(api_key: marys_key.key,
                                 observation: katys_obs.id))
  end

  def test_patching_external_links
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    assert_users_equal(mary, link.user)
    assert_users_equal(rolf, link.observation.user)
    assert_false(link.external_site&.project&.member?(dick))
    site = external_sites(:mycoportal)
    new_url = site.observation_url("222333")
    params = params_patch(id: link.id, set_url: new_url)
    @api_key.update!(user: dick)
    assert_api_fail(params)
    @api_key.update!(user: rolf)
    assert_api_fail(params.merge(set_url: ""))
    assert_api_pass(params)
    assert_equal("222333", link.reload.external_id)
    @api_key.update!(user: mary)
    assert_api_pass(params.merge(set_url: site.observation_url("222334")))
    assert_equal("222334", link.reload.external_id)
    @api_key.update!(user: dick)
    user_group = link.external_site&.project&.user_group
    user_group.users << dick if user_group
    assert_api_pass(params.merge(set_url: site.observation_url("222335")))
    assert_equal("222335", link.reload.external_id)
  end

  def test_deleting_external_links
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    assert_users_equal(mary, link.user)
    assert_users_equal(rolf, link.observation.user)
    assert_false(link.external_site&.project&.member?(dick))
    site = link.external_site
    params = params_delete(id: link.id)
    recreate_params = {
      user: mary,
      observation: link.observation,
      external_site: site,
      external_id: link.external_id
    }
    @api_key.update!(user: dick)
    assert_api_fail(params)
    @api_key.update!(user: rolf)
    assert_api_pass(params)
    assert_nil(ExternalLink.safe_find(link.id))
    link = ExternalLink.create!(recreate_params)
    @api_key.update!(user: mary)
    assert_api_pass(params.merge(id: link.id))
    assert_nil(ExternalLink.safe_find(link.id))
    link = ExternalLink.create!(recreate_params)
    @api_key.update!(user: dick)
    user_group = link.external_site&.project&.user_group
    user_group.users << dick if user_group
    assert_api_pass(params.merge(id: link.id))
    assert_nil(ExternalLink.safe_find(link.id))
  end
end
