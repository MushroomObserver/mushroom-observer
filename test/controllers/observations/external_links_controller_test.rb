# frozen_string_literal: true

require("test_helper")

# This has to be a system test
module Observations
  class ExternalLinksControllerTest < FunctionalTestCase
    def test_new_external_link_form
      obs = observations(:imported_inat_obs)

      login(obs.user.login)
      get(:new, params: { id: obs.id })

      assert_response(:success)
    end

    def test_new_external_link_form_turbo
      obs = observations(:imported_inat_obs)

      login(obs.user.login)
      get(:new, params: { id: obs.id }, format: :turbo_stream)

      assert_response(:success)
      assert_template("shared/_modal_form")
      assert_template("observations/external_links/_form")
    end

    def setup_create_test
      obs  = observations(:agaricus_campestris_obs) # owned by rolf
      obs2 = observations(:agaricus_campestrus_obs) # owned by rolf
      site = ExternalSite.first
      url  = "#{site.base_url}234236523"
      params = {
        id: obs.id,
        external_link: { external_site_id: site, url: url }
      }
      [obs, obs2, site, url, params]
    end

    # not logged in
    def test_create_external_link_not_logged_in
      _obs, _obs2, _site, _url, params = setup_create_test
      post(:create, params:)
      assert_redirected_to(new_account_login_path)
    end

    # dick can't do it
    def test_create_external_link_not_permitted
      obs, _obs2, _site, _url, params = setup_create_test
      login("dick")
      post(:create, params:)
      assert_flash_warning
      assert_redirected_to(permanent_observation_path(obs.id))
    end

    def test_create_external_link_not_permitted_turbo
      _obs, _obs2, _site, _url, params = setup_create_test
      login("dick")
      post(:create, params:, format: :turbo_stream)
      assert_flash_warning
      assert_template("shared/_modal_flash_update")
    end

    # rolf can because he owns it
    def test_create_external_link_owner
      obs, _obs2, site, url, params = setup_create_test
      login("rolf")
      post(:create, params:)
      assert_redirected_to(permanent_observation_path(obs.id))
      assert_flash_success
      assert_users_equal(rolf, ExternalLink.last.user)
      assert_objs_equal(obs, ExternalLink.last.observation)
      assert_objs_equal(site, ExternalLink.last.external_site)
      assert_equal(url, ExternalLink.last.url)
    end

    # And now with Turbo...
    def test_create_external_link_turbo
      _, _obs2, _, _, params = setup_create_test
      login("rolf")
      assert_difference("ExternalLink.count", 1) do
        post(:create, params: params,
                      format: :turbo_stream)
      end
    end

    # bad url
    def test_create_external_link_bad_url
      _obs, _obs2, _site, _url, params = setup_create_test
      login("mary")
      params2 = params.dup
      params2[:external_link][:url] = "bad_url"
      post(:create, params: params2)
      assert_flash_error
    end

    # bad url
    def test_create_external_link_404_response
      _obs, _obs2, _site, _url, params = setup_create_test
      login("mary")
      params2 = params.dup
      params2[:external_link][:url] = "bad_url"
      stub_request(:any, /bad_url/).
        to_return(status: 404, body: "", headers: {})
      post(:create, params: params2)
      assert_flash_error
    end

    def test_create_external_link_good_url_no_scheme
      _obs, _obs2, _site, url, params = setup_create_test
      login("mary")
      params2 = params.dup
      params2[:external_link][:url] = url.delete_prefix("https://")
      post(:create, params: params2)
      assert_flash_success
      assert_equal(url, ExternalLink.last.url)
    end

    def test_create_external_link_good_url_no_www
      _obs, _obs2, _site, url, params = setup_create_test
      login("mary")
      params2 = params.dup
      params2[:external_link][:url] = url.delete_prefix("https://www.")
      post(:create, params: params2)
      assert_flash_success
      assert_equal(url, ExternalLink.last.url)
    end

    # mary can because she's a member of the external site's project
    def test_create_external_link_project_member
      _obs, obs2, site, url, params = setup_create_test
      login("mary")
      params2 = params.dup
      params2[:id] = obs2.id
      post(:create, params: params2)
      assert_redirected_to(permanent_observation_path(obs2.id))
      assert_flash_success
      assert_users_equal(mary, ExternalLink.last.user)
      assert_objs_equal(obs2, ExternalLink.last.observation)
      assert_objs_equal(site, ExternalLink.last.external_site)
      assert_equal(url, ExternalLink.last.url)
    end

    def test_edit_external_link_form
      link = external_links(:imported_inat_obs_inat_link)

      login(link.user.login)
      get(:edit, params: { id: link.id })

      assert_response(:success)
    end

    def test_edit_external_link_form_turbo
      link = external_links(:imported_inat_obs_inat_link)

      login(link.user.login)
      get(:edit, params: { id: link.id }, format: :turbo_stream)

      assert_response(:success)
      assert_template("shared/_modal_form")
      assert_template("observations/external_links/_form")
    end

    def test_update_external_link
      # obs owned by rolf, mary created link and is member of site's project
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      new_url = "#{link.external_site.base_url}different_number"
      params = {
        id: link.id,
        external_link: { url: new_url }
      }

      # not logged in
      put(:update, params:)
      assert_redirected_to(new_account_login_path)

      # dick doesn't have permission
      login("dick")
      put(:update, params:)
      assert_flash_warning

      # mary can
      login("mary")
      put(:update, params:)
      assert_equal(new_url, link.reload.url)
      assert_flash_success

      # rolf can, too
      login("rolf")
      put(:update, params:)
      assert_flash_success

      # bad url
      params[:external_link][:url] = "bad_url"
      put(:update, params:)
      assert_flash_error
    end

    def test_remove_external_link_not_logged_in
      # obs owned by rolf, mary created link and is member of site's project
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      params = { id: link.id }

      # not logged in
      delete(:destroy, params:)
      assert_redirected_to(new_account_login_path)
    end

    # dick doesn't have permission
    def test_remove_external_link_no_permission
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      params = { id: link.id }
      login("dick")
      delete(:destroy, params:)
      assert_flash_warning
    end

    # mary can
    def test_remove_external_link_project_member
      link = external_links(:coprinus_comatus_obs_inaturalist_link)
      params = { id: link.id }
      login("mary")
      delete(:destroy, params:)
      assert_nil(ExternalLink.safe_find(link.id))
      assert_flash_success
    end

    def test_external_check_link_permission
      # obs owned by rolf, mary member of site project
      site = external_sites(:mycoportal)
      obs  = observations(:coprinus_comatus_obs)
      link = external_links(:coprinus_comatus_obs_mycoportal_link)
      @controller.instance_variable_set(:@user, rolf)
      assert_link_allowed(link:)
      assert_link_allowed(obs:, site:)
      @controller.instance_variable_set(:@user, mary)
      assert_link_allowed(link:)
      assert_link_allowed(obs:, site:)
      @controller.instance_variable_set(:@user, dick)
      assert_link_forbidden(link:)
      assert_link_forbidden(obs:, site:)

      dick.update(admin: true)
      assert_link_allowed(link:)
      assert_link_allowed(obs:, site:)
    end

    def assert_link_allowed(**)
      assert_true(@controller.send(:check_external_link_permission!, **))
    end

    def assert_link_forbidden(**)
      assert_false(@controller.send(:check_external_link_permission!, **))
    end
  end
end
