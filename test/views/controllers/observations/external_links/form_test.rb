# frozen_string_literal: true

require "test_helper"

module Views::Controllers::Observations::ExternalLinks
  class FormTest < ComponentTestCase
    def setup
      super
      @external_link = ExternalLink.new
      @observation = observations(:coprinus_comatus_obs)
      @user = users(:rolf)
      @sites = ExternalSite.all
      @site = @sites.first
      @base_urls = @sites.to_h do |site|
        [site.name, site.base_url]
      end
      @html = render_form
    end

    def test_renders_form_with_url_field
      assert_html(@html, "input[name='external_link[url]']")
      assert_html(@html, "input[data-placeholder-target='textField']")
    end

    def test_renders_form_with_site_select
      assert_html(@html, "select[name='external_link[external_site_id]']")
      assert_html(@html, "select[data-placeholder-target='select']")
    end

    def test_renders_hidden_user_id_field
      assert_html(@html,
                  "input[type='hidden'][name='external_link[user_id]']")
    end

    def test_renders_hidden_observation_id_field
      assert_html(@html,
                  "input[type='hidden']" \
                  "[name='external_link[observation_id]']")
    end

    def test_renders_submit_button_for_new_record
      assert_html(@html, "button[type='submit']", text: :ADD.l)
    end

    def test_enables_turbo_by_default
      assert_html(@html, "form[data-turbo='true']")
    end

    def test_auto_determines_url_for_new_external_link
      html = render_form_without_action
      assert_html(html, "form[action*='/external_links']")
    end

    def test_renders_submit_button_for_existing_record
      @external_link = external_links(:coprinus_comatus_obs_mycoportal_link)
      html = render_form

      assert_html(html, "button[type='submit']", text: :UPDATE.l)
    end

    def test_omits_turbo_when_local_true
      html = render_form_local

      assert_no_html(html, "form[data-turbo]")
    end

    def test_auto_determines_url_for_existing_external_link
      @external_link = external_links(:coprinus_comatus_obs_mycoportal_link)
      html = render_form_without_action

      assert_html(html,
                  "form[action*='/external_links/#{@external_link.id}']")
    end

    def test_new_form_omits_external_id_and_relationship
      # @html (from setup) is a new, unpersisted link
      assert_no_html(@html, "input[name='external_link[external_id]']")
      assert_no_html(@html, "select[name='external_link[relationship]']")
    end

    def test_edit_form_renders_external_id_and_url_toggle
      @external_link = external_links(:imported_inat_obs_inat_link)
      html = render_form

      assert_html(html, "input[name='external_link[external_id]']" \
                        "[data-external-link-form-target='externalId']")
      assert_html(html, "input[name='external_link[url]']" \
                        "[data-external-link-form-target='url']")
      assert_html(html, "form[data-controller*='external-link-form']")
    end

    def test_edit_form_renders_relationship_select
      @external_link = external_links(:imported_inat_obs_inat_link)

      assert_html(render_form, "select[name='external_link[relationship]']")
    end

    private

    # Sibling reference within the namespace (`Form` resolves to
    # `Views::Controllers::Observations::ExternalLinks::Form`).
    def render_form
      form = Form.new(
        @external_link,
        observation: @observation,
        sites: @sites,
        site: @site,
        user: @user,
        action: "/test_action",
        local: false
      )
      render(form)
    end

    def render_form_local
      form = Form.new(
        @external_link,
        observation: @observation,
        sites: @sites,
        site: @site,
        user: @user,
        action: "/test_action",
        local: true
      )
      render(form)
    end

    def render_form_without_action
      form = Form.new(
        @external_link,
        observation: @observation,
        sites: @sites,
        site: @site,
        user: @user
      )
      render(form)
    end
  end
end
