# frozen_string_literal: true

require("test_helper")
require("json")

class AjaxControllerTest < FunctionalTestCase
  def good_ajax_request(action, params = {})
    ajax_request(action, params, 200)
  end

  def bad_ajax_request(action, params = {})
    ajax_request(action, params, 500)
  end

  def ajax_request(action, params, status)
    get(action, params: params.dup)
    if @response.response_code == status
      pass
    else
      url = ajax_request_url(action, params)
      msg = "Expected #{status} from: #{url}\n"
      msg += "Got #{@response.response_code}:\n"
      msg += @response.body
      flunk(msg)
    end
  end

  def ajax_request_url(action, params)
    url = "/ajax/#{action}"
    url += "/#{params[:type]}" if params[:type]
    url += "/#{params[:id]}"   if params[:id]
    args = params.except(:type, :id)
    url += "?#{URI.encode_www_form(args)}" if args.any?
    url
  end

  ##############################################################################

  # This is a good place to test this stuff, since the filters are simplified.
  def test_filters
    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,pt;q=0.5"
    good_ajax_request(:test)
    assert_nil(@controller.instance_variable_get(:@user))
    assert_nil(User.current)
    assert_equal(:pt, I18n.locale)
    assert_equal(0, cookies.count)
    assert_equal({ "locale" => "pt" }, session.to_hash)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,xx-xx;q=0.5"
    good_ajax_request(:test)
    assert_equal(:pt, I18n.locale)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,en;q=0.5"
    good_ajax_request(:test)
    assert_equal(:pt, I18n.locale)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "xx-xx,pt-pt"
    good_ajax_request(:test)
    assert_equal(:pt, I18n.locale)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "en-xx,en;q=0.5"
    good_ajax_request(:test)
    assert_equal(:en, I18n.locale)

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "zh-*"
    good_ajax_request(:test)
    assert_equal(:en, I18n.locale)
  end

  # Primers used by the mobile app
  def test_name_primer
    # This name is not deprecated and is used by an observation or two.
    name1 = names(:boletus_edulis)
    item1 = build_name_primer_item(name1)

    # This name is not deprecated and not used by an observation, but a
    # synonym *is* used by an observation, so it should be included.
    name2 = names(:chlorophyllum_rhacodes)
    item2 = build_name_primer_item(name2)

    # This name is deprecated but is used by an observation so it should
    # be included.
    name3 = names(:coprinus_comatus)
    name3.update_attribute(:deprecated, true)
    name3.reload
    item3 = build_name_primer_item(name3)

    get(:name_primer)
    # These assertions may not be stable, in which case we may need to parse
    # the respond body as JSON structure, and test that the structure contains
    # the right elements.
    assert(@response.body.include?(item1),
           "Expected #{@response.body} to include #{item1}.")
    assert(@response.body.include?(item2),
           "Expected #{@response.body} to include #{item2}.")
    assert(@response.body.include?(item3),
           "Expected #{@response.body} to include #{item3}.")
    assert_not(@response.body.include?("Lactarius alpigenes"),
               "Didn't expect primer to include Lactarius alpigenes.")
  end

  def build_name_primer_item(name)
    { id: name.id,
      text_name: name.text_name,
      author: name.author,
      deprecated: name.deprecated,
      synonym_id: name.synonym_id }.to_json
  end

  def test_location_primer
    loc = locations(:burbank)
    item = { id: loc.id, name: loc.name }.to_json
    get(:location_primer)
    assert(@response.body.include?(item),
           "Expected #{@response.body} to include #{item}.")
  end
end
