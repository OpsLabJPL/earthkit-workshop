require 'rubygems'
require 'keepass/password'
require './lib/cescre-auth.rb'
#
# Adds a list of users to the database from a CSV file.
#
# Usage: $ruby util/create_users_from_csv.rb my_users.csv [keepass pattern]
#
# CSV File:
# <user1>,<email1>,<password1>
# ...
# <userN>,<emailN>,<passwordN>
#
# Password field is optional. If missing, it will be auto generated
# using the keepass-password-generator gem

csv_file = ARGV[0]
pattern = ARGV[1] || "uullA{6}"
auth = CESCRE::Auth.new

IO.foreach(csv_file) do |line|
  components = line.split(',')
  username = components[0].strip
  email = components[1].strip

  if components.length < 2
    puts("Skip line with missing params")
    next 
  end
  
  password = components[2] || KeePass::Password.generate(pattern, :remove_lookalikes => true)
  password.strip!

  if CESCRE::Auth.valid_username?(username) and CESCRE::Auth.valid_password?(password)
    if auth.create_user(username, password, email)
      puts "#{username},#{email},#{password}"
    else
      puts "#{username},#{email},NOT added (might already exist)"
    end
  end
end
