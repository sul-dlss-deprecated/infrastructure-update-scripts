# infrastructure-update-scripts

# autoupdate.sh

This script allows us to create pull requests on all the infrastructure projects to update the dependencies
to the most recently released versions.

After running the script head to https://github.com/pulls?utf8=%E2%9C%93&q=is%3Aopen+is%3Apr+org%3Asul-dlss+archived%3Afalse+head%3Aupdate-dependencies+ to see the new pull requests.

## Dependencies
```
brew install hub
```

# grant_revoke_gem_authority.rb

This script allows us to grant rubygems access to organization users.

## Dependencies
```
gem install github_api
```
