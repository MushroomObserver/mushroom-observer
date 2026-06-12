# frozen_string_literal: true

class Tab::Observation::DownloadCSV < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :list_observations_download_as_csv.l
  end

  def path
    with_q_param(new_observations_download_path, @q_param)
  end
end
