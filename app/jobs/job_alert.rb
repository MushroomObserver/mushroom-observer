# frozen_string_literal: true

# Marker exception for review-worthy background-job output routed to the
# #alerts Slack channel via ApplicationJob#alert. It is never raised -
# it is handed to ExceptionNotifier.notify_exception so a job's "a human
# should look at this" summary reuses the same Slack pipeline (and
# de-duplication) as real crashes, while staying visibly distinct from
# them in the channel ("A JobAlert occurred ...").
class JobAlert < StandardError
end
