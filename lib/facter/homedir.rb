# frozen_string_literal: true

require 'etc'

# First get a list of users via the homedir_users fact
#
# An example of this file looks like:
# $ cat /etc/facter/facts.d/homedir_users.yaml
# ---
# homedir_users:
#   - root
#   - jdoe
#
# Missing users will be skipped
#
# If this fact does not exist, all users in /etc/passwd
# will be obtained.
#
users = {}
homedir_users = Facter.value(:homedir_users)
if !homedir_users.nil? && !homedir_users.empty?
  begin
    user = Etc.getpwnam(u)
    users[user.name] = user.dir
  rescue
    next
  end
else
  Etc.passwd do |sshuser|
    users[sshuser.name] = sshuser.dir
  end
end

users.each do |user_name, user_dir|
  Facter.add("home_#{user_name}") do
    setcode do
      user_dir
    end
  end
end
