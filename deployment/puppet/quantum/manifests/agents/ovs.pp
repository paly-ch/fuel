class quantum::agents::ovs (
  $package_ensure       = 'present',
  $enabled              = true,
  $bridge_uplinks       = ['br-ex:eth2'],
  $bridge_mappings      = ['physnet1:br-ex'],
  $integration_bridge   = 'br-int',
  $enable_tunneling     = true,
  $local_ip             = undef,
  $tunnel_bridge        = 'br-tun'
) {

  include 'quantum::params'
  if $enable_tunneling and ! $local_ip {
    fail('Local ip for ovs agent must be set when tunneling is enabled')
  }

  include 'quantum::params'
  
  if $::quantum::params::ovs_agent_package {
    Package['quantum'] ->  Package['quantum-plugin-ovs-agent']

    $ovs_agent_package = 'quantum-plugin-ovs-agent'

    package { 'quantum-plugin-ovs-agent':
      name    => $::quantum::params::ovs_agent_package,
      ensure  => $package_ensure,
    }
  } else {
    $ovs_agent_package = $::quantum::params::ovs_server_package
  }

  Package[$ovs_agent_package] -> Quantum_plugin_ovs<||>

  l23network::l2::bridge{$integration_bridge:
    external_ids => "bridge-id=${integration_bridge}",
    ensure       => present,
    skip_existing=> true,
    #require      => Service['quantum-plugin-ovs-service'],
  }

  if $enable_tunneling {
    l23network::l2::bridge{$tunnel_bridge:
      external_ids => "bridge-id=${tunnel_bridge}",
      ensure       => present,
      skip_existing=> true,
      #require      => Service['quantum-plugin-ovs-service'],
    }

    quantum_plugin_ovs {
      'OVS/local_ip': value => $local_ip;
    }
  }

  if ! $enable_tunneling {
    quantum::plugins::ovs::bridge{$bridge_mappings:
      #require      => Service['quantum-plugin-ovs-service'],
    }
    quantum::plugins::ovs::port{$bridge_uplinks:
      #require      => Service['quantum-plugin-ovs-service'],
    }
  }

  if $enabled {
    $service_ensure = 'running'
  } else {
    $service_ensure = 'stopped'
  }

  if ! defined(Package['python-amqp']) {
    package { 'python-amqp':
      ensure => present,
    }
  }

  Quantum_config<||> ~> Service['quantum-plugin-ovs-service']
  Quantum_plugin_ovs<||> ~> Service['quantum-plugin-ovs-service']

  L23network::L2::Bridge<||> -> Service['quantum-plugin-ovs-service']

  service { 'quantum-plugin-ovs-service':
    name       => $::quantum::params::ovs_agent_service,
    enable     => $enabled,
    ensure     => $service_ensure,
    hasstatus  => true,
    hasrestart => true,
    provider   => $::quantum::params::service_provider,
  }

  Package['python-amqp'] -> Package[$ovs_agent_package] -> Service['quantum-plugin-ovs-service']
  Class['quantum'] -> Service['quantum-plugin-ovs-service']
}
