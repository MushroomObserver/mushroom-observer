# frozen_string_literal: true

class API2
  # Cannot update locations if there is an herbarium there.
  class MustNotHaveAnyHerbaria < FatalError
  end
end
