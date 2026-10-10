namespace :auth do
  desc "Delete expired browser sessions and API tokens (schedule daily, e.g. with cron)"
  task prune: :environment do
    sessions = Session.prune_expired!
    tokens = ApiToken.prune_expired!

    puts "Removed #{sessions} expired sessions and #{tokens} expired API tokens."
  end
end
