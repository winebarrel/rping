Gem::Specification.new do |spec|
  spec.name              = 'rping'
  spec.version           = '0.1.2'
  spec.summary           = 'rping is a ruby implementation of ping.'
  spec.require_paths     = %w(lib)
  spec.files             = %w(README) + Dir.glob('bin/**/*') + Dir.glob('lib/**/*')
  spec.author            = 'winebarrel'
  spec.email             = 'sgwr_dts@yahoo.co.jp'
  spec.homepage          = 'https://bitbucket.org/winebarrel/rping'
  spec.bindir            = 'bin'
  spec.executables << 'rping'
end
