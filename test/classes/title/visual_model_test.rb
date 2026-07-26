# frozen_string_literal: true

require("test_helper")

class Title::VisualModelTest < UnitTestCase
  def test_page_title_and_document_title
    vm = visual_models(:visual_model_one)
    title = Title.for(vm)

    assert_equal(vm.name, title.page_title)
    assert_equal(vm.name, title.document_title)
  end
end
