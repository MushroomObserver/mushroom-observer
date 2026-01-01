# frozen_string_literal: true

require "test_helper"

class ExternalLinkFormTest < ComponentTestCase

  def setup
    super
    @external_link = ExternalLink.new
    @observation = observations(:coprinus_comatus_obs)
    @user = users(:rolf)
    @sites = ExternalSite.all
    @site = @sites.first
    @base_urls = @sites.each_with_object({}) do |site, hash|
      hash[site.name] = site.base_url
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
    assert_html(@html, "input[type='hidden'][name='external_link[user_id]']")
  end

  def test_renders_hidden_observation_id_field
    assert_html(@html,
                "input[type='hidden'][name='external_link[observation_id]']")
  end

  def test_renders_submit_button_for_new_record
    assert_html(@html, "input[type='submit'][value='#{:ADD.l}']")
    assert_html(@html, "input.btn.btn-default")
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

    assert_html(html, "input[type='submit'][value='#{:UPDATE.l}']")
  end

  def test_omits_turbo_when_local_true
    html = render_form_local

    assert_no_html(html, "form[data-turbo]")
  end

  def test_auto_determines_url_for_existing_external_link
    @external_link = external_links(:coprinus_comatus_obs_mycoportal_link)
    html = render_form_without_action

    assert_html(html, "form[action*='/external_links/#{@external_link.id}']")
  end

  private

  def render_form
    form = Components::ExternalLinkForm.new(
      @external_link,
      observation: @observation,
      sites: @sites,
      site: @site,
      user: @user,
      action: "/test_action",
      id: "external_link_form",
      local: false
    )
    render(form)
  end

  def render_form_local
    form = Components::ExternalLinkForm.new(
      @external_link,
      observation: @observation,
      sites: @sites,
      site: @site,
      user: @user,
      action: "/test_action",
      id: "external_link_form",
      local: true
    )
    render(form)
  end

  def render_form_without_action
    form = Components::ExternalLinkForm.new(
      @external_link,
      observation: @observation,
      sites: @sites,
      site: @site,
      user: @user
    )
    render(form)
  end
end
