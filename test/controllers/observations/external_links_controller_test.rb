# frozen_string_literal: true

require("test_helper")

# This has to be a system test
module Observations
  class ExternalLinksControllerTest < FunctionalTestCase
    # def test_add_external_link
    #   obs  = observations(:agaricus_campestris_obs) # owned by rolf
    #   obs2 = observations(:agaricus_campestrus_obs) # owned by rolf
    #   site = ExternalSite.first
    #   url  = "http://valid.url"
    #   params = {
    #     type: "add",
    #     id: obs.id,
    #     site: site.id,
    #     value: url
    #   }

    #   # not logged in
    #   bad_ajax_request(:external_link, params)

    #   # dick can't do it
    #   login("dick")
    #   bad_ajax_request(:external_link, params)

    #   # rolf can because he owns it
    #   login("rolf")
    #   good_ajax_request(:external_link, params)
    #   assert_equal(@response.body, ExternalLink.last.id.to_s)
    #   assert_users_equal(rolf, ExternalLink.last.user)
    #   assert_objs_equal(obs, ExternalLink.last.observation)
    #   assert_objs_equal(site, ExternalLink.last.external_site)
    #   assert_equal(url, ExternalLink.last.url)

    #   # bad url
    #   login("mary")
    #   bad_ajax_request(:external_link, params.merge(value: "bad url"))

    #   # mary can because she's a member of the external site's project
    #   login("mary")
    #   good_ajax_request(:external_link, params.merge(id: obs2.id))
    #   assert_equal(@response.body, ExternalLink.last.id.to_s)
    #   assert_users_equal(mary, ExternalLink.last.user)
    #   assert_objs_equal(obs2, ExternalLink.last.observation)
    #   assert_objs_equal(site, ExternalLink.last.external_site)
    #   assert_equal(url, ExternalLink.last.url)
    # end

    # def test_edit_external_link
    #   # obs owned by rolf, mary created link and is member of site's project
    #   link    = ExternalLink.first
    #   new_url = "http://another.valid.url"
    #   params = {
    #     type: "edit",
    #     id: link.id,
    #     value: new_url
    #   }

    #   # not logged in
    #   bad_ajax_request(:external_link, params)

    #   # dick doesn't have permission
    #   login("dick")
    #   bad_ajax_request(:external_link, params)

    #   # mary can
    #   login("mary")
    #   good_ajax_request(:external_link, params)
    #   assert_equal(new_url, link.reload.url)

    #   # rolf can, too
    #   login("rolf")
    #   good_ajax_request(:external_link, params)

    #   # bad url
    #   bad_ajax_request(:external_link, params.merge(value: "bad url"))
    # end

    # def test_remove_external_link
    #   # obs owned by rolf, mary created link and is member of site's project
    #   link   = ExternalLink.first
    #   params = {
    #     type: "remove",
    #     id: link.id
    #   }

    #   # not logged in
    #   bad_ajax_request(:external_link, params)

    #   # dick doesn't have permission
    #   login("dick")
    #   bad_ajax_request(:external_link, params)

    #   # mary can
    #   login("mary")
    #   good_ajax_request(:external_link, params)
    #   assert_nil(ExternalLink.safe_find(link.id))
    # end

    # def test_check_link_permission
    #   # obs owned by rolf, mary member of site project
    #   site = external_sites(:mycoportal)
    #   obs  = observations(:coprinus_comatus_obs)
    #   link = external_links(:coprinus_comatus_obs_mycoportal_link)
    #   @controller.instance_variable_set(:@user, rolf)
    #   assert_link_allowed(link)
    #   assert_link_allowed(obs, site)
    #   @controller.instance_variable_set(:@user, mary)
    #   assert_link_allowed(link)
    #   assert_link_allowed(obs, site)
    #   @controller.instance_variable_set(:@user, dick)
    #   assert_link_forbidden(link)
    #   assert_link_forbidden(obs, site)

    #   dick.update(admin: true)
    #   assert_link_allowed(link)
    #   assert_link_allowed(obs, site)
    # end

    # def assert_link_allowed(*args)
    #   assert_nothing_raised do
    #     @controller.send(:check_link_permission!, *args)
    #   end
    # end

    # def assert_link_forbidden(*args)
    #   assert_raises(RuntimeError) do
    #     @controller.send(:check_link_permission!, *args)
    #   end
    # end
  end
end
