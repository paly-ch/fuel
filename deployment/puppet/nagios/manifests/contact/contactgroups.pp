define nagios::contact::contactgroups(
$alias = false
) {

notify {$name:}
  nagios_contactgroup { $name:
    ensure => present,
    alias  => $alias,
    target => "/etc/nagios3/test/contactgroups.cfg",
  }
}