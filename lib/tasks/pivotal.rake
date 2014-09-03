namespace :pivotal do
  desc "Refresh Pivotal cache."
  task(:update => :environment) do
    FileUtils.rm_rf(MO.pivotal_cache)
    Pivotal.get_stories(:verbose)
  end
end
