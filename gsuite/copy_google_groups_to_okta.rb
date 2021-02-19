require "google/apis/admin_directory_v1"
require "googleauth"
require "googleauth/stores/file_token_store"
require "oktakit"
require "pry"

OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
APPLICATION_NAME = "APPNAME".freeze
CREDENTIALS_PATH = "/Users/himanshu/Desktop/temp_google_code/credentials.json".freeze
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
def initialize_api()
  service = Google::Apis::AdminDirectoryV1::DirectoryService.new
  service.client_options.application_name = APPLICATION_NAME
  service.authorization = authorize
  service
end

def google_groups()
  service = initialize_api()
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
  groups
end

def google_group_members(group)
  service = initialize_api()
  next_page = nil
  gmembers = []
  begin
    gmembers_response = service.list_members(group.id, page_token: next_page)
    tmp_members = gmembers_response.members
    next if tmp_members.nil?
    gmembers = gmembers.concat(tmp_members)
    next_page = gmembers_response.next_page_token
  end while next_page
  gmembers
end

def okta_client()
  client = Oktakit.new(token: ENV["OKTA_API_Key"], organization: 'dev-63719753')
end

def create_google_groups_in_okta()
  groups = google_groups()
  groups.each do |group|
    options = {
      "profile": {
        "name": group.name,
        "description": group.description
      }
    }
    puts "creating group \"" + group.name + "\""
    client = okta_client
    client.add_group(options)
  end
end

def copy_google_group_membership_to_okta()
  ggroups = google_groups()
  client_okta = okta_client()
  options = {
    "query": {
      "filter": "type eq \"OKTA_GROUP\""
    }
  }
  ogroups = client_okta.list_groups(options).first
  ousers = client_okta.list_users.first

  ggroups.each do |ggroup|
    ogroup = ogroups.select { |h| h["profile"]["name"] == ggroup.name}.first
    if (Date.parse(ogroup.created) != Date.today())
      puts "Updating Group created not today, Exiting."
      break;
    end
    if (ogroup.type != "OKTA_GROUP")
      puts "Updating non Okta group, exiting.."
      break;
    end
    puts ggroup.name
    google_group_members(ggroup).each do |gmember|
      if (gmember.status != "ACTIVE"){
        puts "google group : " ggroup.name + "member email: " + gmember.email + " - Is suspended, ignoring"
        next
      }
      omember = ousers.select { |h| h["profile"]["email"] == gmember.email}.first.id
      puts "Adding " + omember.email + " to " + ogroup.name
      client_okta.add_user_to_group(ogroup.id, omember.id)
    end
  end
end

# create_google_groups_in_okta()
# copy_google_group_membership_to_okta()

