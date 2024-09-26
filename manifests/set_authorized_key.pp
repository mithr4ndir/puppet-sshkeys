# == Defined Type: sshkeys::set_authorized_key
#
#   Add a key to a user's authorized_keys file.
#
# === Parameters
#
#   [*local_user*]
#     The user who will receive the key.
#
#   [*remote_user*]
#     The user of the key being obtained.
#
#   [*ensure*]
#     Status of the key.
#
#   [*options*]
#     Any ssh key options.
#
#   [*target*]
#     The destination authorized_keys file.
#
#   [*downcase*]
#     Whether to downcase the remote_node name in the query request.
#     The results_node name returned will always be lowercase.
#     Default: true
#
define sshkeys::set_authorized_key (
  String $local_user,
  String $remote_user,
  String $ensure                  = 'present',
  Variant[Undef,String] $options  = undef,
  Variant[Undef,String] $target   = undef,
  Boolean $downcase               = true
) {
  # Parse the name
  $parts = split($remote_user, '@')
  $remote_username = $parts[0]

  if $downcase {
    $remote_node   = downcase($parts[1])
    $results_node  = $remote_node
  }
  else {
    $remote_node   = $parts[1]
    $results_node  = downcase($parts[1])
  }

  $home = getvar("::home_${local_user}")
  if ($home == undef) {
    notify { "Cannot determine the home dir of user '${local_user}' for key from ${remote_username}@${remote_node}. Skipping SSH authorized key registration": }
  } else {
    # Figure out the target
    if $target {
      $target_real = $target
    } else {
      $target_real = "${home}/.ssh/authorized_keys"
    }

    Ssh_authorized_key {
      user   => $local_user,
      target => $target_real,
    }

    if $ensure == 'absent' {
      ssh_authorized_key { $name:
        ensure => absent,
      }
    } else {
      # Query for the sshpubkey
      $query = "facts[certname, value] { name = 'sshpubkey_${remote_username}' and certname in inventory[certname] { certname ~ '${remote_node}'}}"
 
      # Execute the PuppetDB query
      $results = puppetdb_query($query)
      # Process the results
      if $results and length($results) > 0 {
        $key = split($results[0]['value'], ' ') # look at the 
        if ($key[0] !~ /^(ssh-...)/) {
          err("Can't parse key for ${remote_username}")
        } else {
          $keytype = $key[0]
          $modulus = $key[1]
          ssh_authorized_key { $name:
            ensure  => $ensure,
            type    => $keytype,
            key     => $modulus,
            options => $options,
          }
        }
      } else {
        notify { "No SSH key found for ${remote_username} on ${remote_node}": }
      }
    }
  }
}
