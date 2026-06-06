# frozen_string_literal: true

require("test_helper")
require("builder")

class API2HelperTest < ActionView::TestCase
  include API2Helper

  def test_json_api_key_returns_hash_with_key_fields
    api_key = api_keys(:rolfs_api_key)
    result = json_api_key(api_key)

    assert_equal(api_key.id, result[:id],
                 "Expected api_key id in json hash")
    assert_equal(api_key.key.to_s, result[:key],
                 "Expected api_key key string in json hash")
  end

  def test_xml_float_renders_tag_with_rounded_value
    builder = Builder::XmlMarkup.new
    xml_float(builder, "distance", 3.14159, 2)
    doc = Nokogiri::XML(builder.target!)

    assert(doc.at_xpath("//distance[@type='float']"),
           "Expected float tag with type attribute")
    assert_equal("3.14", doc.at_xpath("//distance").text,
                 "Expected value rounded to 2 places")
  end

  def test_xml_naming_reason_blank_notes_omits_content
    reason = Naming::Reason.new({}, 1)
    builder = Builder::XmlMarkup.new
    xml_naming_reason(builder, "reason", reason)
    doc = Nokogiri::XML(builder.target!)

    assert(doc.at_xpath("//reason[@category]"),
           "Expected reason tag with category attribute")
    assert_equal("", doc.at_xpath("//reason").text,
                 "Expected no text content when notes are blank")
  end

  def test_xml_naming_reason_with_notes_includes_content
    reason = Naming::Reason.new({ 1 => "Observed in person" }, 1)
    builder = Builder::XmlMarkup.new
    xml_naming_reason(builder, "reason", reason)
    doc = Nokogiri::XML(builder.target!)

    assert(doc.at_xpath("//reason[@category]"),
           "Expected reason tag with category attribute")
    assert_equal("Observed in person", doc.at_xpath("//reason").text,
                 "Expected notes as tag text content")
  end
end
