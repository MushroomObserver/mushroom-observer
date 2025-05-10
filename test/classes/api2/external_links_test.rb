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

  def test_getting_external_links
    other_obs = observations(:agaricus_campestris_obs)
    link1 = external_links(:coprinus_comatus_obs_mycoportal_link)
    link2 = external_links(:coprinus_comatus_obs_inaturalist_link)
    link3 = ExternalLink.create!(user: rolf, observation: other_obs,
                                 external_site: link1.external_site,
                                 url: "#{link1.external_site.base_url}876876")
    params = { method: :get, action: :external_link }

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

    assert_api_pass(params.merge(url: link2.url))
    assert_api_results([link2])
  end

  def test_posting_external_links
    marys_obs = observations(:detailed_unknown_obs)
    rolfs_obs = observations(:agaricus_campestris_obs)
    katys_obs = observations(:amateur_obs)
    marys_key = api_keys(:marys_api_key)
    rolfs_key = api_keys(:rolfs_api_key)
    site = external_sites(:mycoportal)
    base_url = site.base_url
    params = {
      method: :post,
      action: :external_link,
      api_key: rolfs_key.key,
      observation: rolfs_obs.id,
      external_site: site.id,
      url: "#{base_url}blah"
    }
    assert_api_pass(params)
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:observation))
    assert_api_fail(params.except(:external_site))
    assert_api_fail(params.except(:url))
    assert_api_fail(params.merge(api_key: "spammer"))
    assert_api_fail(params.merge(observation: "spammer"))
    assert_api_fail(params.merge(external_site: "spammer"))
    assert_api_fail(params.merge(url: "spammer"))
    assert_api_fail(params.merge(observation: marys_obs.id))
    assert_api_fail(params.merge(api_key: marys_key.key)) # already exists!
    assert_api_pass(params.merge(api_key: marys_key.key,
                                 observation: katys_obs.id))
  end

  def test_patching_external_links
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    assert_users_equal(mary, link.user)
    assert_users_equal(rolf, link.observation.user)
    assert_false(link.external_site&.project&.member?(dick))
    site = external_sites(:mycoportal)
    base_url = site.base_url
    new_url = "#{base_url}something_else"
    params = {
      method: :patch,
      action: :external_link,
      api_key: @api_key.key,
      id: link.id,
      set_url: new_url
    }
    @api_key.update!(user: dick)
    assert_api_fail(params)
    @api_key.update!(user: rolf)
    assert_api_fail(params.merge(set_url: ""))
    assert_api_pass(params)
    assert_equal(new_url, link.reload.url)
    @api_key.update!(user: mary)
    assert_api_pass(params.merge(set_url: "#{new_url}2"))
    assert_equal("#{new_url}2", link.reload.url)
    @api_key.update!(user: dick)
    user_group = link.external_site&.project&.user_group
    user_group.users << dick if user_group
    assert_api_pass(params.merge(set_url: "#{new_url}3"))
    assert_equal("#{new_url}3", link.reload.url)
  end

  def test_deleting_external_links
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    assert_users_equal(mary, link.user)
    assert_users_equal(rolf, link.observation.user)
    assert_false(link.external_site&.project&.member?(dick))
    site = link.external_site
    params = {
      method: :delete,
      action: :external_link,
      api_key: @api_key.key,
      id: link.id
    }
    recreate_params = {
      user: mary,
      observation: link.observation,
      external_site: site,
      url: link.url
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
