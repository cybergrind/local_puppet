class kpi::base_devel () {
  include kpi::packages

  $python2 = [ 'python2', 'python2-numpy', 'ipython2', 'python2-virtualenv' ]
  kpi::install { $python2: }

  $scala = [ 'jdk', 'scala', 'scala-docs', 'sbt', 'java-jline' ]
  kpi::install { $scala: }

  $other = [ 'go', 'nodejs', 'npm', ]
  kpi::install { $other: }

  $editors = ['emacs-nox', 'vim']
  kpi::install { $editors: }

  $tools = ['git', 'mercurial', 'subversion',
            'docker', 'docker-compose', 'docker-machine', 'python2-docker-py']
  kpi::install { $tools: }

  file {"/root": ensure => directory}
  kpi::home::vim_setup {"vim-root": user=>"root", dir=>"/root"}
}
