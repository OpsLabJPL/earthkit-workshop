module CESCRE
  CONFIG = {
    :workshop => 'ROIPAC-2013-07',

    :ec2 => {
      :key_pair => 'cescre-launcher-test',
      :security_group => 'sg-3eaeb352',
      :subnet => 'subnet-76c0b91f'
    },

    :redis => {
      :host => 'localhost',
      :port => 6379
    },

    :ssl => {
      :enabled => true,
      :certificate => './cescre_ssl_dev.crt',
      :key => './cescre_ssl_dev.key'
    }
  }
end