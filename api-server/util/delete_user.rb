require 'rubygems'
require 'bundler/setup'

require './lib/cescre-admin.rb'
require 'trollop'

opts = Trollop::options do
    opt(:username, "username of account to delete", :type => :string)
end

if !opts[:username].nil? then
    username = opts[:username]
    print("do you REALLY want to delete the user #{username}??? (yes/no) ")
    answer = STDIN.readline.delete("\n")

    if answer == 'yes' then
        admin = CESCRE::Admin.new
        status = admin.delete_user(username)
        if status == 1 then
            puts("user #{username} has been deleted")
        else
            puts("could not delete #{username} from the database")
        end
    end
end