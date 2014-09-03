namespace :pivotal do
  desc "Refresh Pivotal cache."
  task(:update => :environment) do
    Pivotal.get_stories(:verbose)
  end

  desc "Purge then populate Pivotal cache."
  task(:purge => :environment) do
    FileUtils.rm_rf(MO.pivotal_cache)
    Pivotal.get_stories(:verbose)
  end
end
