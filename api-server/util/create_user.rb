require 'rubygems'
require 'bundler/setup'

require './lib/cescre-auth.rb'
require 'trollop'

# TODO: prevent password from appearing in the console

opts = Trollop::options do
    opt(:username, "username of account to create", :type => :string)
    opt(:email, "account owner's email address", :type => :string)
    opt(:password, "account password", :type => :string)
end

if !opts[:username].nil? and !opts[:email].nil? then
    username = opts[:username]
    email = opts[:email]
    if !CESCRE::Auth.valid_username?(username) then
        STDERR.puts("usernames can only contain alpha-numeric characters, periods, dashes, and underscores")
        exit
    end

    if opts[:password].nil? then
        print("password for user #{username}: ")
        password = STDIN.readline().delete("\n").delete("\t")
        print("verify password for user #{username}: ")
        password2 = STDIN.readline().delete("\n").delete("\t")
        if password != password2 then
            STDERR.puts("passwords do not match")
            exit
        end
    else
        password = opts[:password]
    end
    if !CESCRE::Auth.valid_password?(password) then
        STDERR.puts("passwords must be at least 8 characters and no longer than 256 characters in length")
        exit
    end

    auth = CESCRE::Auth.new
    if auth.create_user(username, password, email) then
        puts("user #{username} created")
    else
        STDERR.puts("could not create user #{username}, user likely already exists")
    end
end