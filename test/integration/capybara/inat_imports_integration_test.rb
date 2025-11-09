# frozen_string_literal: true

require("test_helper")

# Test things that are untestable in integration tests
class InatImportsTest < CapybaraIntegrationTestCase
  include Inat::Constants

  def test_inat_import_no_imports_designated
    login(mary)
    visit(new_inat_import_path)

    fill_in("inat_username", with: "anything")
    click_on("Submit")

    assert_flash_text(:inat_list_xor_all.l)
    assert_selector("#title", text: :inat_import_create_title.l)
  end

  def test_inat_import_resubmit_with_same_user_imput
    skip("under construction")
    user = users(:mary)
    ids = "123456789"
    stub_count_request(ids: ids, inat_username: user.inat_username)

    login(user.login)
    visit(new_inat_import_path)
    fill_in("inat_ids", with: ids)
    fill_in("inat_username", with: user.inat_username)

    click_on("Submit")
    assert_selector("#title", text: :inat_import_create_title.l)

    click_on("Submit")
    debugger
    assert(
      page.current_url.start_with?(INAT_AUTHORIZATION_URL),
      "Expected redirect to #{INAT_AUTHORIZATION_URL}, got #{page.current_url}"
    )
  end

  def stub_count_request(inat_username:, ids: nil, body: "{}")
    stub_request(
      :get,
      "#{API_BASE}/observations" \
      "?iconic_taxa=#{ICONIC_TAXA}" \
      "&id=#{ids}" \
      "&only_id=true&page=1&per_page=1" \
      "&user_id=#{inat_username}" \
      "&verifiable=any" \
      "&without_field=Mushroom%20Observer%20URL"
    ).to_return(status: 200, body: body, headers: {})
  end
end
