
require 'github_api'

github = Github.new do |config|
  # config.endpoint    = 'https://github.company.com/api/v3'
  # config.site        = 'https://github.company.com'
  # config.oauth_token = 'token'
  # config.adapter     = :net_http
  # config.ssl         = {:verify => false}
  # config.repo        = 'ios-here-newgen'
end

newgen_repo = github.repo
pulls = newgen.pull_requests
closed_pulls_list = pulls.list(state: 'closed').count

binding.pry
