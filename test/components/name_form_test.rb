# frozen_string_literal: true

require "test_helper"

class NameFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  def test_new_form
    html = render_form(model: Name.new(rank: "Species"), name_string: "")

    # Form structure
    assert_html(html, "form#name_form")
    assert_html(html, "form[action='/names'][method='post']")
    assert_html(html, "input[type='submit'][value='#{:CREATE.t}']")

    # Help and fields
    assert_includes(html, :form_names_detailed_help.l)
    assert_html(html, "input[name='name[icn_id]']")
    assert_includes(html, :form_names_icn_id.l)
    assert_includes(html, :form_names_identifier_help.l)

    # Rank select
    assert_html(html, "select[name='name[rank]']")
    assert_includes(html, :Rank.l)
    assert_html(html, "option[value='Species']")
    assert_html(html, "option[value='Genus']")
    assert_html(html, "option[value='Family']")

    # Status select
    assert_html(html, "select[name='name[deprecated]']")
    assert_includes(html, :Status.l)
    assert_includes(html, :ACCEPTED.l)
    assert_includes(html, :DEPRECATED.l)

    # Text name and author fields
    assert_html(html, "textarea[name='name[text_name]'][data-autofocus]")
    assert_includes(html, :form_names_text_name.l)
    assert_includes(html, :form_names_text_name_help.l)
    assert_html(html, "textarea[name='name[author]']")
    assert_includes(html, :Authority.l)
    assert_includes(html, :form_names_author_help.l)

    # Citation field
    assert_html(html, "textarea[name='name[citation]']")
    assert_includes(html, :Citation.l)
    assert_includes(html, :form_names_citation_help.l)

    # Notes field with between content
    assert_html(html, "textarea[name='name[notes]']")
    assert_includes(html, :form_names_taxonomic_notes.l)
    assert_includes(html, :shared_textile_help.l)
    assert_html(html, "div.mark")

    # No misspelling fields for new form without misspelling param
    assert_not_includes(html, "name[misspelling]")
    assert_not_includes(html, "name[correct_spelling]")
  end

  def test_new_form_with_name_string
    name_string = "Agaricus campestris"
    html = render_form(model: Name.new(rank: "Species"),
                       name_string: name_string)

    assert_html(html, "textarea[name='name[text_name]']")
    assert_includes(html, name_string)
  end

  def test_edit_form
    name = names(:coprinus_comatus)
    html = render_form(model: name, name_string: name.text_name)

    assert_html(html, "input[type='submit'][value='#{:SAVE_EDITS.t}']")
    assert_html(html, "form[action='/names/#{name.id}'][method='post']")
    assert_html(html, "input[name='_method'][value='patch']")
  end

  def test_locked_form
    locked_name = names(:lactarius_alpinus)
    locked_name.update!(locked: true)
    html = render_form(model: locked_name, name_string: locked_name.text_name)

    # Hidden fields instead of editable ones
    assert_html(html, "input[type='hidden'][name='name[rank]']")
    assert_html(html, "input[type='hidden'][name='name[deprecated]']")
    assert_html(html, "input[type='hidden'][name='name[text_name]']")
    assert_html(html, "input[type='hidden'][name='name[author]']")

    # Display text
    assert_includes(html, :show_name_locked.tp.as_displayed)
    rank_text = :"Rank_#{locked_name.rank.to_s.downcase}".l
    assert_includes(html, rank_text)
    status_text = locked_name.deprecated ? :DEPRECATED.l : :ACCEPTED.l
    assert_includes(html, status_text)
  end

  def test_form_with_misspelling
    name = names(:coprinus_comatus)
    html = render_form(
      model: name,
      name_string: name.text_name,
      misspelling: true,
      correct_spelling: "Coprinus comatus"
    )

    assert_html(html, "input[name='name[misspelling]'][type='checkbox']")
    assert_includes(html, :form_names_misspelling.l)
    assert_html(html, "input[name='name[correct_spelling]']")
    assert_includes(html, :form_names_misspelling_it_should_be.l)
  end

  def test_locked_form_hides_misspelling_fields
    locked_name = names(:lactarius_alpinus)
    locked_name.update!(locked: true)
    html = render_form(
      model: locked_name,
      name_string: locked_name.text_name,
      misspelling: false
    )

    assert_not_includes(html, "name[misspelling]")
  end

  private

  def render_form(model:, name_string:, misspelling: nil, correct_spelling: nil)
    render(Components::NameForm.new(
             model,
             user: @user,
             name_string: name_string,
             misspelling: misspelling,
             correct_spelling: correct_spelling
           ))
  end
end
