# frozen_string_literal: true

require "test_helper"

class NameFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @name = names(:coprinus_comatus)
  end

  # --- New record (create mode) ---

  def test_renders_create_button_for_new_record
    html = render_new_form

    assert_html(html, "input[type='submit'][value='#{:CREATE.t}']")
  end

  def test_form_action_for_new_record
    html = render_new_form

    assert_html(html, "form[action='/names'][method='post']")
  end

  def test_form_has_correct_id
    html = render_new_form

    assert_html(html, "form#name_form")
  end

  # --- Edit record (update mode) ---

  def test_renders_save_edits_button_for_existing_record
    html = render_edit_form

    assert_html(html, "input[type='submit'][value='#{:SAVE_EDITS.t}']")
  end

  def test_form_action_for_existing_record
    html = render_edit_form

    # Edit form submits to /names/:id with PATCH method
    assert_html(html, "form[action='/names/#{@name.id}'][method='post']")
    assert_html(html, "input[name='_method'][value='patch']")
  end

  # --- Editable fields (unlocked name) ---

  def test_renders_detailed_help_block
    html = render_new_form

    assert_includes(html, :form_names_detailed_help.l)
  end

  def test_renders_icn_id_field
    html = render_new_form

    assert_html(html, "input[name='name[icn_id]']")
    assert_includes(html, :form_names_icn_id.l)
    assert_includes(html, :form_names_identifier_help.l)
  end

  def test_renders_rank_select_with_options
    html = render_new_form

    assert_html(html, "select[name='name[rank]']")
    assert_includes(html, :Rank.l)
    # Check some rank options exist
    assert_html(html, "option[value='Species']")
    assert_html(html, "option[value='Genus']")
    assert_html(html, "option[value='Family']")
  end

  def test_renders_status_select
    html = render_new_form

    assert_html(html, "select[name='name[deprecated]']")
    assert_includes(html, :Status.l)
    assert_includes(html, :ACCEPTED.l)
    assert_includes(html, :DEPRECATED.l)
  end

  def test_renders_text_name_textarea_with_value
    name_string = "Agaricus campestris"
    html = render_new_form(name_string: name_string)

    assert_html(html, "textarea[name='name[text_name]']")
    assert_includes(html, name_string)
    assert_includes(html, :form_names_text_name.l)
    assert_includes(html, :form_names_text_name_help.l)
  end

  def test_renders_text_name_textarea_with_autofocus
    html = render_new_form

    assert_html(html, "textarea[name='name[text_name]'][data-autofocus]")
  end

  def test_renders_author_textarea
    html = render_new_form

    assert_html(html, "textarea[name='name[author]']")
    assert_includes(html, :Authority.l)
    assert_includes(html, :form_names_author_help.l)
  end

  # --- Locked fields (locked name, non-admin) ---

  def test_renders_hidden_fields_when_locked
    html = render_locked_form

    assert_html(html, "input[type='hidden'][name='name[rank]']")
    assert_html(html, "input[type='hidden'][name='name[deprecated]']")
    assert_html(html, "input[type='hidden'][name='name[text_name]']")
    assert_html(html, "input[type='hidden'][name='name[author]']")
  end

  def test_renders_locked_name_display_text
    html = render_locked_form

    assert_includes(html, :show_name_locked.tp.as_displayed)
  end

  def test_locked_form_shows_rank_display_text
    html = render_locked_form

    rank_text = :"Rank_#{@name.rank.to_s.downcase}".l
    assert_includes(html, rank_text)
  end

  def test_locked_form_shows_status_display_text
    html = render_locked_form

    status_text = @name.deprecated ? :DEPRECATED.l : :ACCEPTED.l
    assert_includes(html, status_text)
  end

  # NOTE: Admin mode tests require sessions which are disabled in unit tests.
  # Admin mode behavior (locked checkbox, editable fields when locked) is
  # tested via controller/integration tests instead.

  # --- Citation field ---

  def test_renders_citation_field
    html = render_new_form

    assert_html(html, "textarea[name='name[citation]']")
    assert_includes(html, :Citation.l)
    assert_includes(html, :form_names_citation_help.l)
  end

  # --- Misspelling fields ---

  def test_renders_misspelling_fields_when_misspelling_provided
    html = render_form_with_misspelling

    assert_html(html, "input[name='name[misspelling]'][type='checkbox']")
    assert_includes(html, :form_names_misspelling.l)
    assert_html(html, "input[name='name[correct_spelling]']")
    assert_includes(html, :form_names_misspelling_it_should_be.l)
  end

  def test_does_not_render_misspelling_fields_when_misspelling_nil
    html = render_new_form

    assert_not_includes(html, "name[misspelling]")
    assert_not_includes(html, "name[correct_spelling]")
  end

  def test_does_not_render_misspelling_fields_when_locked_non_admin
    html = render_locked_form_with_misspelling

    assert_not_includes(html, "name[misspelling]")
  end

  # --- Notes field ---

  def test_renders_notes_field
    html = render_new_form

    assert_html(html, "textarea[name='name[notes]']")
    assert_includes(html, :form_names_taxonomic_notes.l)
    assert_includes(html, :shared_textile_help.l)
  end

  def test_renders_notes_field_with_between_content
    html = render_new_form

    # The between content (warning) is rendered with mark class
    assert_html(html, "div.mark")
  end

  private

  def render_new_form(name_string: "", misspelling: nil, correct_spelling: nil)
    name = Name.new(rank: "Species")
    render(Components::NameForm.new(
             name,
             user: @user,
             name_string: name_string,
             misspelling: misspelling,
             correct_spelling: correct_spelling
           ))
  end

  def render_edit_form
    render(Components::NameForm.new(
             @name,
             user: @user,
             name_string: @name.text_name
           ))
  end

  def render_locked_form
    locked_name = names(:lactarius_alpinus)
    locked_name.update!(locked: true)
    render(Components::NameForm.new(
             locked_name,
             user: @user,
             name_string: locked_name.text_name
           ))
  end

  def render_locked_form_with_misspelling
    locked_name = names(:lactarius_alpinus)
    locked_name.update!(locked: true)
    render(Components::NameForm.new(
             locked_name,
             user: @user,
             name_string: locked_name.text_name,
             misspelling: false
           ))
  end

  def render_form_with_misspelling
    render(Components::NameForm.new(
             @name,
             user: @user,
             name_string: @name.text_name,
             misspelling: true,
             correct_spelling: "Coprinus comatus"
           ))
  end
end
