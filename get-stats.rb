
require 'github_api'

github = Github.new do |config|
  config.endpoint    = 'https://github.paypal.com/api/v3'
  config.site        = 'https://github.paypal.com'
  config.oauth_token = '<ommited>'
  config.adapter     = :net_http
  config.ssl         = {:verify => false}
  config.repo        = 'ios-here-newgen'
end


pull_reqs = github.pull_requests.all(:user => 'PayPal-Mobile', :repo => 'ios-here-newgen', :state => 'closed', :per_page => 100)

# key: user id
users = {}

# key: pullreq URL
pulls = {}


pull_reqs.each_page do |page|
  page.each do |pull|
    # Skip any unmerged pull requests
    next if not pull.merged_at
    
    # Ensure that this pull req is saved
    pulls[pull.url] ||= pull
    
    # Ensure that the user exists
    user = (users[pull.user.id] ||= pull.user)
    
    # Count the number of pull requests per user
    user.number_of_pull_requests ||= 0
    user.number_of_pull_requests += 1
  end
end

pull_req_comments = github.pull_requests.comments.all(:user => 'PayPal-Mobile', :repo => 'ios-here-newgen', :state => 'closed', :per_page => 100)

pull_req_comments.each_page do |page|
  page.each do |comment|
    # Find the comment's pull req
    pull = pulls[comment.pull_request_url]

    # If we didn't find this comment's pull in pulls, then it must be on a non-merged pull request, so skip it.
    next if not pull
    
    # Ensure that the user exists
    user = (users[comment.user.id] ||= comment.user)
      
    # Only count comments that aren't people commenting on their own pull requests
    if user.id != pull.user.id then
      user.number_of_pull_comments_given ||= 0
      user.number_of_pull_comments_given += 1

      users[pull.user.id].number_of_pull_comments_attracted ||= 0
      users[pull.user.id].number_of_pull_comments_attracted += 1
    end
    
  end
end

# print stats
printf "%20s   %5s   %13s   %18s   %31s\n", "login", "pulls", "comments made", "comments attracted", "comments attracted per pull req" 
users.values.sort_by{|u| -u.number_of_pull_requests}.each do |user|
  printf "%20s   %5d   %13d   %18d   %31f\n", user.login, (user.number_of_pull_requests or 0), (user.number_of_pull_comments_given or 0), (user.number_of_pull_comments_attracted or 0), ((user.number_of_pull_comments_attracted or 1).to_f / (user.number_of_pull_requests or 1).to_f)
end


# pull req merges per person: git log --pretty="format:%ae %s" | awk '/.*Merge pull request.*/ { ++c[$1]; } END { for(cc in c) printf "%5d %s\n",c[cc],cc; }'| sort -r
# non-merge commits per person: git log --no-merges --pretty=format:%an | awk '{ ++c[$0]; } END { for(cc in c) printf "%5d %s\n",c[cc],cc; }'| sort -r

