class kpi::base_devel () {
  include kpi::packages
  include kpi::packages::optional

  # $python2 = [ 'python2', 'python2-numpy', 'ipython2', 'python2-virtualenv' ]
  # kpi::install { $python2: }

  # $scala = [ 'jdk', 'scala', 'scala-docs', 'sbt', 'java-jline' ]
  # kpi::install { $scala: }

  $other = [ 'go', 'nodejs', 'npm', 'yarn', 'jdk']
  kpi::install { $other: }

  $editors = ['emacs-nox', 'vim']
  kpi::install { $editors: }

  $tools = ['git', 'docker', 'docker-compose']
  kpi::install { $tools: }

  file {"/root": ensure => directory}
  kpi::home::vim_setup {"vim-root": user=>"root", dir=>"/root"}
}
