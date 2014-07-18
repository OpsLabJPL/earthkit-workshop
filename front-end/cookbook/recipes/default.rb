package 'ruby1.9.1'
package 'ruby1.9.1-dev'
package 'nginx-light'
package 'git'

include_recipe 'nodejs::install_from_binary'

# bash 'npm_install' do
#   user 'ubuntu'
#   cwd '/home/ubuntu/repo/lab-ui-mockup'
#   code <<-EOH
#   npm install
#   EOH
# end

# bash 'install_grunt_bower' do
#   cwd '/home/ubuntu/repo/lab-ui-mockup'
#   code <<-EOH
#   npm install grunt-cli bower -g
#   EOH
# end

# gem_package 'compass' do
#   action :install
# end

# bash 'bower_install' do
#   user 'ubuntu'
#   cwd '/home/ubuntu/repo/lab-ui-mockup'
#   code <<-EOH
#   bower install
#   EOH
# end