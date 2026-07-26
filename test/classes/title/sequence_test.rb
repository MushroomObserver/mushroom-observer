# frozen_string_literal: true

require("test_helper")

# `page_title` is used by `Views::FullPageBase#add_show_title` as the
# H1 + browser-tab title. Sequence's locus is shown in the body, so
# the title identifies the sequence by its observation.
class Title::SequenceTest < UnitTestCase
  def test_page_title_and_document_title
    seq = sequences(:local_sequence)
    title = Title.for(seq)

    assert_equal(:show_sequence_title.l(id: seq.observation_id),
                 title.page_title)
    # `document_title` is aliased to `page_title`.
    assert_equal(title.page_title, title.document_title)
  end
end
