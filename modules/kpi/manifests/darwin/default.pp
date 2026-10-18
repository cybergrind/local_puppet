# One `defaults write`, skipped when `defaults read` already returns the value.
define kpi::darwin::default (String $domain, String $key, Variant[Boolean, Integer, String] $value) {
  $type = $value ? {
    Boolean => 'bool',
    Integer => 'int',
    default => 'string',
  }
  # `defaults read` prints booleans as 1/0
  $expected = $value ? {
    true    => '1',
    false   => '0',
    default => String($value),
  }

  exec { "defaults ${domain} ${key}":
    command  => "/usr/bin/defaults write ${domain} '${key}' -${type} '${value}'",
    unless   => "/bin/test \"$(/usr/bin/defaults read ${domain} '${key}' 2>/dev/null)\" = '${expected}'",
    provider => shell,
  }
}
