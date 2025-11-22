# frozen_string_literal: true

require("application_system_test_case")

class ListFormSystemTest < ApplicationSystemTestCase
  def test_multi_autocompleter
    @browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    species_list = species_lists("first_species_list")
    visit("/species_lists/#{species_list.id}/write_in/new")
    assert_selector("body.write_in__new")
    assert_field("list_members")
    assert_field("list_name_id", type: :hidden)

    name1 = names("coprinus_comatus")
    name2 = names("agaricus_campestris")
    name3 = names("stereum_hirsutum")
    fill_in("list_members", with: "Agaricus campestris")
    assert_field("list_name_id", with: name2.id, type: :hidden)
    @browser.keyboard.type(:return)
    assert_field("list_members", with: /Agaricus campestris/)
    @browser.keyboard.type("Coprinus com")
    assert_selector(".auto_complete") # wait
    assert_selector(".auto_complete ul li a", text: "Coprinus comatus")
    @browser.keyboard.type(:down, :tab)
    assert_field("list_members", with: /Coprinus comatus/)
    assert_field("list_name_id", with: "#{name2.id},#{name1.id}", type: :hidden)
    @browser.keyboard.type(:return)
    sleep(1)
    @browser.keyboard.type(:return)
    @browser.keyboard.type("Stereum hirs")
    assert_selector(".auto_complete") # wait
    assert_selector(".auto_complete ul li a", text: "Stereum hirsutum")
    @browser.keyboard.type(:down, :tab)
    assert_field("list_members", with: /Stereum hirsutum/)
    assert_field("list_name_id", with: "#{name2.id},#{name1.id},#{name3.id}",
                                 type: :hidden)
  end

  def test_multi_autocompleter_paste
    @browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    species_list = species_lists("first_species_list")
    visit("/species_lists/#{species_list.id}/write_in/new")
    assert_selector("body.write_in__new")
    assert_field("list_members")
    assert_field("list_name_id", type: :hidden)

    name1 = names("coprinus_comatus")
    name2 = names("agaricus_campestris")
    name3 = names("stereum_hirsutum")
    fill_in(
      "list_members",
      with: "Agaricus campestris\nCoprinus comatus\nStereum hirsutum"
    )
    assert_field("list_members", with: /Agaricus campestris/)
    sleep(1)
    assert_field("list_name_id", with: "#{name2.id},#{name1.id},#{name3.id}",
                                 type: :hidden)
  end
end
