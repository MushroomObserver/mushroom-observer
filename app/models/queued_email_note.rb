# encoding: utf-8
class QueuedEmailNote < ActiveRecord::Base
  belongs_to :queued_email
end
