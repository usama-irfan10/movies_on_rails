require "io/console"

namespace :users do
  desc "Create a user. Usage: bin/rails users:create EMAIL=you@example.com (the password is prompted for)"
  task create: :environment do
    email = ENV["EMAIL"].presence || abort("Usage: bin/rails users:create EMAIL=you@example.com")
    console = IO.console || abort("A terminal is required to enter the password.")

    password = console.getpass("Password (min #{User::MIN_PASSWORD_LENGTH} characters): ")
    confirmation = console.getpass("Repeat password: ")

    user = User.new(email_address: email, password:, password_confirmation: confirmation)
    if user.save
      puts "Created user #{user.email_address}."
    else
      abort "Could not create user: #{user.errors.full_messages.to_sentence}"
    end
  end
end
