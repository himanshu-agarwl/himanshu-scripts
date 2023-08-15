require 'json'
require "csv"

def write_group_users_to_csv(jsonfilename, csvfilename)
  file = File.read(jsonfilename)
  users_hash = JSON.parse(file)

  CSV.open(csvfilename, "wb") do |csv|
    csv << [ "displayName", "firstName", "lastName", "login email", "employmentStatus", "status", "title", "isPartofShift"]
    users_hash.each do |user|
      title = user['profile']['title']
      ifPartofShift = (title != nil and (title.include?("Regional Director") or title.include?("Clinician Manager") or title.include?("Practice Manager")))
      csv << [ user['profile']['displayName'], user['profile']['firstName'], user['profile']['lastName'], user['profile']['login'], user['profile']['employmentStatus'], user['status'], title, ifPartofShift ]
    end
  end
end