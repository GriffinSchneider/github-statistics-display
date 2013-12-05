
if not ARGV[1]
  print "No git repo specified\n"
  exit(1)
end


# key: user id
users = {}

# key: pullreq URL
pulls = {}

##############################
# Get Github API stats
##############################
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

##############################
# Get local git stats
##############################
email_map = {
  "griffinschneider@gmail.com" => "gschneider@paypal.com",
  "jordanchriss@gmail.com" => "chrijordan@paypal.com",
  "ma@x.com" => "mmetral@paypal.com",
  "jaredegan@gmail.com" => "jaegan@paypal.com"
}

merges_per_person_command = %q[ git log --pretty="format:%ae %s" | awk '/.*Merge pull request.*/ { ++c[$1]; } END { for(cc in c) printf "%5d %s\n",c[cc],cc; }' ]
non_merge_commits_per_person_command = %q[ git log --no-merges --pretty=format:%ae | awk '{ ++c[$0]; } END { for(cc in c) printf "%5d %s\n",c[cc],cc; }' ]

merges_per_person_string = `cd "#{ARGV[1]}" && #{merges_per_person_command}`
non_merge_commits_per_person_string = `cd "#{ARGV[1]}" && #{non_merge_commits_per_person_command}`

merges_per_person_string.each_line do |line|
  email = line.split[1]
  if email_map[email] then email = email_map[email] end
  user_name = email.split("@")[0]
  
  user = users.values.find { |user| user.login === user_name}
  if user
    user.number_of_pull_request_merge_commits ||= 0
    user.number_of_pull_request_merge_commits += Integer(line.split[0])
  end
end

non_merge_commits_per_person_string.each_line do |line|
  email = line.split[1]
  if email_map[email] then email = email_map[email] end
  user_name = email.split("@")[0]
  
  user = users.values.find { |user| user.login === user_name}
  if user
    user.number_of_non_merge_commits ||= 0
    user.number_of_non_merge_commits += Integer(line.split[0])
  end
end

##############################
# Generate HTML
##############################
table_rows = ""

maximum_number_of_pull_requests = users.values.max_by{|u| u.number_of_pull_requests or 0}.number_of_pull_requests
maximum_number_of_pull_comments_given = users.values.max_by{|u| u.number_of_pull_comments_given or 0 }.number_of_pull_comments_given
maximum_number_of_pull_request_merge_commits = users.values.max_by{|u| u.number_of_pull_request_merge_commits or 0 }.number_of_pull_request_merge_commits
maximum_number_of_non_merge_commits = users.values.max_by{|u| u.number_of_non_merge_commits or 0 }.number_of_non_merge_commits

users.values.sort_by{|u| -u.number_of_pull_requests}.each do |user|
  num_pull_reqs = (user.number_of_pull_requests or 0)
  num_comments_given = (user.number_of_pull_comments_given or 0)
  num_comments_attracted = (user.number_of_pull_comments_attracted or 0)
  num_pulls_merged = (user.number_of_pull_request_merge_commits or 0)
  num_commits = (user.number_of_non_merge_commits or 0)
  table_rows += <<-eos
    <tr>
      <td> <img src=\"#{user.avatar_url}\" width=42 height=42/> #{user.login} </td> 
      <td #{'class = "maximum"' if num_pull_reqs == maximum_number_of_pull_requests}> #{num_pull_reqs} </td> 
      <td #{'class = "maximum"' if num_comments_given == maximum_number_of_pull_comments_given}> #{num_comments_given} </td> 
      <td> #{num_comments_attracted} </td> 
      <td #{'class = "maximum"' if num_pulls_merged == maximum_number_of_pull_request_merge_commits}> #{num_pulls_merged} </td> 
      <td #{'class = "maximum"' if num_commits == maximum_number_of_non_merge_commits}> #{num_commits} </td> 
    </tr>
  eos
end

# make html
html_string = <<-eos
<html>
  <head>
    <meta http-equiv="refresh" content="60" >
    <style>
      table {
        font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
        width: 100%;
        border-collapse: collapse;
      }
      td, th {
        font-size: 1.1em;
        padding: 5px 7px 5px 7px;
        text-align: center;
      }
      th {
        font-size: 1.1em;
        padding-top: 5px;
        padding-bottom: 4px;
        background-color: #D6EBFF;
        color: #000000;
      }
      tr:nth-child(odd) {
        color: #000000;
        background-color: #D6EBFF
      }
      td:nth-child(1) {
        white-space: nowrap;
        text-align: left;
      }
      img {
        vertical-align: middle;
      }
      .maximum {
        font-weight: bold;
        color: #4BBD00;
      }
    </style>
  </head>

  <body>
    <table>
      <tr>
        <th></th>
        <th>Pull Requests Made</th>
        <th>Pull Request Comments Made</th>
        <th>Pull Request Comments Attracted</th>
        <th>Pull Requests Merged</th>
        <th>Non-Merge Commits Made</th>
      </tr>
      #{table_rows}
    </table>
  </body>
eos

File.open('stuff.html', 'w') do |f| f.write html_string end

##############################
# Print statistics
##############################
printf "%20s   %5s   %13s   %18s   %31s\n", "login", "pulls", "comments made", "comments attracted", "comments attracted per pull req" 
users.values.sort_by{|u| -u.number_of_pull_requests}.each do |user|
  printf "%20s   %5d   %13d   %18d   %31f\n", user.login, (user.number_of_pull_requests or 0), (user.number_of_pull_comments_given or 0), (user.number_of_pull_comments_attracted or 0), ((user.number_of_pull_comments_attracted or 1).to_f / (user.number_of_pull_requests or 1).to_f)
end



