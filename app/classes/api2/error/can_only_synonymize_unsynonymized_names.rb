# frozen_string_literal: true

class API2
  # We're not allowing client to merge to sets of synonyms.  Even more, we're
  # only allowing them to synonymize unsynonmized names with other names.
  # (The name they synonymize it with, however, can have synonyms.)
  class CanOnlySynonymizeUnsynonymizedNames < FatalError
  end
end
