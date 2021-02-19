require "octokit"
require "csv"

ORG_NAME = "NONAME"
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

# Extract members and their email 
def extract_org_members(org_name, filter="all")
  members = octokit_client.org_members org_name, :filter => filter
  while octokit_client.last_response.rels[:next]
    members.concat octokit_client.get(octokit_client.last_response.rels[:next].href)
  end
  return members
end

def summarize_github_email_mfa_status
  all_members = extract_org_members(ORG_NAME)
  members_without_mfa = extract_org_members(ORG_NAME, "2fa_disabled")
  members_login_without_mfa = members_without_mfa.collect { |member| member[:login] }
  CSV.open("github-users.csv", "wb") do |csv|
    csv << ["Github Login", "Name", "Email Address", "MFA enabled"]
    all_members.each do |member|
      user = octokit_client.user(member[:login])
      csv << [user[:login], user[:name], user[:email], !members_login_without_mfa.include?(user[:login])]
    end
  end
end

summarize_github_email_mfa_status()