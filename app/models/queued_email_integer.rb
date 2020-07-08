# frozen_string_literal: true

#
# = QueuedEmailInteger
#
#  Contains a single integer, e.g., name id.
#  Each QueuedEmail record can own zero or more of these
class QueuedEmailInteger < ApplicationRecord
  belongs_to :queued_email
end
