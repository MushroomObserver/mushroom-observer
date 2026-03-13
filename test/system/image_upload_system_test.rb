# frozen_string_literal: true

require("application_system_test_case")

class ImageUploadSystemTest < ApplicationSystemTestCase
  def test_create_glossary_term_with_image_upload
    setup_image_dirs

    user = users("rolf")
    login!(user)

    visit(new_glossary_term_path)
    assert_selector("body.glossary_terms__new")

    # Fill in glossary term fields
    unique_name = "Fungal Cap #{Time.now.to_i}"
    fill_in("glossary_term_name", with: unique_name)
    fill_in("glossary_term_description", with: "The top part of a mushroom")

    # Attach image file (file input is inside styled button, not visible)
    image_path = Rails.root.join("test/images/Coprinus_comatus.jpg")
    attach_file("glossary_term_upload_image", image_path, visible: false)

    # Fill in copyright fields
    fill_in("glossary_term_upload_copyright_holder", with: user.name)
    select(Time.zone.now.year.to_s, from: "glossary_term_upload_copyright_year")

    # License is pre-selected with user's default (since we fixed
    # the value/display swap)

    # Submit and verify both Image and GlossaryTerm are created
    assert_difference("Image.count", 1) do
      assert_difference("GlossaryTerm.count", 1) do
        within("form[action='/glossary_terms']") do
          click_button("Save")
        end
      end
    end

    # Verify we're on the show page after successful creation
    assert_selector("body.glossary_terms__show")

    # Verify the glossary term was created correctly
    glossary_term = GlossaryTerm.find_by(name: unique_name)
    assert(glossary_term, "Glossary term should be created")
    assert_equal("The top part of a mushroom", glossary_term.description)

    # Verify the image was associated
    assert_equal(1, glossary_term.images.count,
                 "Glossary term should have one image")
  end

  # Test that the file input rejects non-image files with an alert
  def test_file_input_rejects_non_image_files
    user = users("rolf")
    login!(user)

    # Use the projects form which has file_field_with_label
    visit(new_project_path)
    assert_selector("body.projects__new")

    # Create a temporary text file (non-image)
    text_file = Tempfile.new(["test", ".txt"])
    text_file.write("This is not an image")
    text_file.close

    begin
      # Attach the non-image file and expect an alert
      alert_text = accept_alert do
        attach_file("upload_image", text_file.path, visible: false)
      end

      assert_equal("Please select an image file (JPG, PNG, GIF, etc.)",
                   alert_text)
    ensure
      text_file.unlink
    end
  end
end
