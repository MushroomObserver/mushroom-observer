# frozen_string_literal: true

#
# = QueuedEmailString
#
#  Contains a single fixed-length string.
#  Each QueuedEmail record can own zero or more of these
class QueuedEmailString < ApplicationRecord
  belongs_to :queued_email
end
