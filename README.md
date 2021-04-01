# himanshu-scripts


<h2>Extract Github user email & MFA status</h2> 

- You would need Github Personal Access Token to authenticate to github. Create one from https://github.com/settings/tokens with scope as "read:org", "read:user" & "user:email". 
- In case your organization uses SSO for login to github, authorize the access token you just created to be used with SSO. Instructions at https://docs.github.com/en/github/authenticating-to-github/authorizing-a-personal-access-token-for-use-with-saml-single-sign-on
- Install octokit gem by running `gem install octokit` 
- Run the script using command `GITHUB_ORG_NAME="<org-name>" ruby github/github_users_email_mfa.rb`
- The output should be generated in "github-users.csv" in current directory. 