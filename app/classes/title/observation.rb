# frozen_string_literal: true

# Plain-text title for the browser tab `<title>`. `text_name` is the
# denormalized binomial-only column — no author, no id, no markup. The
# title helper prepends "OBSERVATION <id>:" so we don't need those
# here. (The visible page heading is built by
# `Views::Layouts::Header::ObjectTitle` via
# `Observations::ConsensusNameLink` -- wraps the consensus name in a
# link, so Observation never reaches `page_title` at all; no override
# needed here, the base Title#page_title default is unused for it.)
class Title::Observation < Title
  def document_title
    @object.text_name
  end
end
