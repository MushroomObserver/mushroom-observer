# frozen_string_literal: true

# Member-facing observation sub-tab: download the project's
# observations (`?q=...` scoped query carried over via `q_param`).
class Tab::Project::ObservationDownload < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :download.ti
  end

  def path
    with_q_param(new_observations_download_path, @q_param)
  end

  def alt_title
    "download"
  end
end
