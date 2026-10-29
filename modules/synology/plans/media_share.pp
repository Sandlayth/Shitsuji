# @summary Give a dedicated, non-admin DSM account access to one share
#
# Used by the media stack (Jellyfin & co. on another host) so it never holds
# admin credentials. The password is only set when the account is created;
# rotate it with `synouser --setpw`.
#
# @param targets Synology hosts
# @param share Shared folder name (e.g. a USB share or a media volume share)
# @param user Account to create/grant
# @param password Password for a newly created account; pass it from a prompt or env, never the repo
# @param access RW or RO
#
# @example
#   bolt plan run synology::media_share -t nas share=usbshare2-2 password=$(cat ~/media.cred)
plan synology::media_share (
  TargetSpec                  $targets,
  String                      $share,
  String                      $user     = 'media',
  Sensitive[String]           $password = Sensitive(''),
  Enum['RW', 'RO']            $access   = 'RW',
) {
  $bin = '/usr/syno/sbin'

  get_targets($targets).each |$t| {
    if !run_command("${bin}/synouser --get ${user}", $t, '_catch_errors' => true).ok {
      if $password.unwrap.empty { fail_plan("${user} does not exist on ${t.name}; pass password= to create it") }
      out::message("${t.name}: creating DSM user ${user}")
      # Positional args: name pw "full name" expired(0) mail privilege(0)
      run_command("${bin}/synouser --add ${user} \"\$SHITSUJI_PW\" 'Media stack (non-admin)' 0 '' 0", $t,
        '_env_vars' => { 'SHITSUJI_PW' => $password.unwrap })
    }

    $acl = run_command("${bin}/synoshare --get '${share}'", $t).first['stdout']
    $list = $access ? { 'RW' => 'RW list', 'RO' => 'RO list' }
    $members = $acl.match(Regexp("${list} \\.+\\[([^\\]]*)\\]"))[1].split(',')
    if !($user in $members) {
      out::message("${t.name}: granting ${user} ${access} on ${share}")
      run_command("${bin}/synoshare --setuser '${share}' ${access} + ${user}", $t)
    }
  }
}
