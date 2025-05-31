namespace :admin do
  desc "Create initial admin user"
  task create: :environment do
    email = ENV['ADMIN_EMAIL'] || 'admin@prmetrics.io'
    password = ENV['ADMIN_PASSWORD'] || 'changeme123'
    
    if Admin.exists?(email: email)
      puts "Admin with email #{email} already exists"
    else
      Admin.create!(
        email: email,
        password: password,
        password_confirmation: password
      )
      puts "Admin created successfully!"
      puts "Email: #{email}"
      puts "Password: #{password}"
      puts "Please change this password after first login!"
    end
  end
end