require "octokit"
require "csv"

ORG_NAME = ENV["GITHUB_ORG_NAME"]
ALL_PRS=[]
CUTOFF_DATE = "31-08-2021"
COMPLETED_REPOS = [
  "mdcollab/mdcollab",
]

def octokit_client
  if @client.nil?
    print 'Github Access token:'
    # We hide the entered characters before to ask for the api token
    system 'stty -echo'
    access_token = $stdin.gets.chomp
    system 'stty echo'
    puts
    @client = Octokit::Client.new(:access_token => access_token)
  end
  return @client
end

def list_repositories
  octokit_client.auto_paginate = true
  repos = octokit_client.organization_repositories(ORG_NAME)
  print("number of repos: ", repos.count, "\n")
  return repos
end

def list_pull_requests(repo)
  octokit_client.auto_paginate = false
  print("Collecting PRs for: ", repo, "\n")
  page_number = 0
  while true do
    page_number = page_number + 1
    print("Checking PRs on page: ", page_number, "\n")
    prs = octokit_client.pull_requests(repo, {state: 'closed', per_page: 100, page: page_number})
    break if prs.empty?
    prs.each do |pr|
      ALL_PRS << pr if !pr.merged_at.nil? && pr.merged_at > Time.parse(CUTOFF_DATE)
    end
  end
end

def pr_exporter
  repos = list_repositories
  repos.each do |repo|
    if COMPLETED_REPOS.include?(repo.full_name)
      print("Ignoring ", repo.full_name)
    else
      prs = list_pull_requests(repo.full_name)
    end
  end
end

def write_to_csv(prs)
  CSV.open("prs.csv", "wb") do |csv|
    csv << [ "URL", "REPOSITORY", "PR_NUMBER", "TITLE", "USER", "BODY", "MERGED_AT", "MERGED_TO"]
    prs.each do |pr|
      csv << [pr.html_url, pr.head.repo.full_name, pr.number, pr.title, pr.user.login, pr.body, pr.merged_at, pr.base.ref ]
    end
  end
end