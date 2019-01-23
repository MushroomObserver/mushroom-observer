# frozen_string_literal: true
#
# = QueuedEmailNote
#
#  Contains a single arbitrary-length string.
#  Each QueuedEmail record can own zero or more of these
class QueuedEmailNote < ApplicationRecord
  belongs_to :queued_email
end
