#!/usr/bin/env ruby

# 1. Get a personal access token from GitHub (https://github.com/settings/tokens)
#    with the following scopes enabled:
#    * public_repo
#    * read:org
#    * user:email
# 2. Set an ENV variable named 'GITHUB_TOKEN' containing your token
# 3. Gem install github_api
# 4. Then run this script:
#    $ ruby ./grant_revoke_gem_authority.rb
#
# To also revoke ownership from users whose email addresses are not in the list:
# $ WITH_REVOKE=true ruby ./grant_revoke_gem_authority.rb
#
# To print more information on what the script is doing:
# $ VERBOSE=true ruby ./grant_revoke_gem_authority.rb

require 'github_api'
require 'open3'

AUTHORIZATION_TOKEN = ENV['GITHUB_TOKEN'] || raise("GitHub authorization token was not found in the GITHUB_TOKEN environment variable")
ORGANIZATION_NAME = 'sul-dlss'
# Some GitHub user instances do not have an email address defined,
# so start with the prior list of addresses (registered with Rubygems.org)
KNOWN_COMMITTER_EMAIL_ADDRESSES = {
  'aaron-collier' => 'aaron.collier@stanford.edu',
  'aeschylus' => 'scipioaffricanus@gmail.com',
  'anarchivist' => 'mark.matienzo@gmail.com',
  'atz' => 'ohiocore@gmail.com',
  'jcoyne' => 'digger250@gmail.com',
  'jermnelson' => 'jermnelson@gmail.com',
  'jkeck' => 'jessie.keck@gmail.com',
  'jmartin-sul' => 'john.martin@stanford.edu',
  'justinlittman' => 'justinlittman@gmail.com',
  'mejackreed' => 'phillipjreed@gmail.com',
  'mjgiarlo' => 'leftwing@alumni.rutgers.edu',
  'ndushay' => 'ndushay@stanford.edu',
  'peetucket' => 'peter@mangiafico.org',
  'sul-devops-team' => 'sul-devops-team@lists.stanford.edu'
}
# Some GitHub repositories are named differently from their gems
KNOWN_MISMATCHED_GEM_NAMES = { }
# GitHub repositories with matching gems that aren't from sul-dlss
FALSE_POSITIVES = %w[microservices argo eadsax sir-trevor-rails assembly stacks media swap quimby Jcrop gssapi osullivan rialto robot-master]
# Gems that do not have their own GitHub repositories
HANGERS_ON = []
# Email addresses that are known not to be registered at rubygems.org
SKIP_EMAILS = %w[ggeisler@gmail.com ]
VERBOSE = ENV.fetch('VERBOSE', false)
WITH_REVOKE = ENV.fetch('WITH_REVOKE', false)

puts "(Hang in there! This script takes a couple minutes to run.)"

github = Github.new(oauth_token: AUTHORIZATION_TOKEN, auto_pagination: true)

# Get the IDs of the Access and Infra GitHub teams from the sul-dlss org
org = github.orgs.teams.list(org: ORGANIZATION_NAME)
access_team_id = org.select { |team| team.name == 'Access Team' }.first.id
infra_team_id = org.select { |team| team.name == 'Infrastructure Team' }.first.id

team_members = github.orgs.teams.list_members(access_team_id).to_a + github.orgs.teams.list_members(infra_team_id).to_a
# Start with the prior (known to work) list of email addresses
committer_map = KNOWN_COMMITTER_EMAIL_ADDRESSES.dup
team_members.each do |member|
  user = github.users.get(user: member.login)
  # Move along if the user doesn't have an email addy or if there's already an entry in the map
  next if !user.respond_to?(:email) || user.email.nil? || user.email.empty? || !committer_map[user.login].nil?
  committer_map[user.login] = user.email
end
committer_emails = committer_map.values.sort.uniq

# Keep track of things
@errors = []
@bogus_gem_names = []
@gem_names = HANGERS_ON

def exists?(name)
  return false if FALSE_POSITIVES.include?(name)
  system("gem owner #{name} > /dev/null 2>&1")
end

def replace_known_mismatch(name)
  KNOWN_MISMATCHED_GEM_NAMES.fetch(name, name)
end

github.repos.list(org: ORGANIZATION_NAME).each do |repo|
  puts "Looking at #{repo.name}" if VERBOSE
  name = replace_known_mismatch(repo.name)
  if exists?(name)
    puts "\tFound #{name}" if VERBOSE
    @gem_names << name
  else
    @bogus_gem_names << repo.full_name
  end
end

def gem_owner_with_error_check(gemname, params)
  command = "gem owner #{gemname} #{params}"
  puts "running: #{command}" if VERBOSE
  Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
    @errors << "#{gemname} #{params}: #{stdout.read.chomp}" unless wait_thr.value.success?
  end
end

@gem_names.sort.each do |gemname|
  current_committers = `gem owner #{gemname} | grep -e ^-`.split("\n")
  current_committers.collect! { |cc| cc.sub(/^.\s+/,'')}

  if WITH_REVOKE
    puts "Gem: #{gemname}" if VERBOSE
    committers_to_remove = current_committers - committer_emails
    remove_params = committers_to_remove.map { |email| "-r #{email}" }.join(' ')
    gem_owner_with_error_check(gemname, remove_params)
  end

  committers_to_add = committer_emails - current_committers - SKIP_EMAILS
  add_params = committers_to_add.map { |email| "-a #{email}" }.join(' ')
  gem_owner_with_error_check(gemname, add_params)
end

if @bogus_gem_names.any? && VERBOSE
  $stderr.puts("WARNING: These repositories do not have gems:\n - #{@bogus_gem_names.sort.join("\n - ")}")
  $stderr.puts("\n")
end

if @errors.any?
  $stderr.puts("The following errors were encountered:")
  $stderr.puts(%(#{@errors.sort.join("\n")}))
end
