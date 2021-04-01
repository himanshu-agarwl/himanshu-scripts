require "google/apis/admin_directory_v1"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
require "csv"
require "pry"

OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
APPLICATION_NAME = ENV["APPLICATION_NAME"].freeze
CREDENTIALS_PATH = "credentials.json".freeze
# The file token.yaml stores the user's access and refresh tokens, and is
# created automatically when the authorization flow completes for the first
# time.
TOKEN_PATH = "token.yaml".freeze
SCOPES = [Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_GROUP_READONLY, Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER_READONLY]


def authorize
  client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
  token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
  authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPES, token_store
  user_id = "default"
  credentials = authorizer.get_credentials user_id
  if credentials.nil?
    url = authorizer.get_authorization_url base_url: OOB_URI
    puts "Open the following URL in the browser and enter the " \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end


# Initialize the API
service = Google::Apis::AdminDirectoryV1::DirectoryService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

groups = []
next_page = nil
begin
    group_response = service.list_groups(customer:    "my_customer",
                                         order_by:    "email",
                                         page_token: next_page)
    groups = groups.concat(group_response.groups)
    next_page = group_response.next_page_token
end while next_page
puts groups.count
puts "No Groups found" if groups.empty?
output_file = CSV.open("grouups_users.csv", 'wb')
entry = ["Group Name", "Group Email", "Group Member Email", "Group Member Role", "Group Member Status"]
output_file << entry
groups.each do |group|
    puts group.name
    next_page = nil
    members = []
    begin
        members_response = service.list_members(group.id, page_token: next_page)
        tmp_members = members_response.members
        next if tmp_members.nil?
        members = members.concat(tmp_members)
        next_page = members_response.next_page_token
    end while next_page
    if members.nil? then 
        entry = [ group.name, group.email, "N/A", "N/A", "N/A"]
        output_file << entry
        next
    end
    puts members.count

    members.each do |member|
        entry = [ group.name, group.email, member.email, member.role, member.status]
        output_file << entry
    end
end