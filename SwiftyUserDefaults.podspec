Pod::Spec.new do |s|
  s.name = 'SwiftyUserDefaults'
  s.version = '6.0.0'
  s.license = 'MIT'
  s.summary = 'Swifty API for UserDefaults'
  s.homepage = 'https://github.com/sunshinejr/SwiftyUserDefaults'
  s.authors = { 'Radek Pietruszewski' => 'this.is@radex.io', 'Łukasz Mróz' => 'thesunshinejr@gmail.com' }
  s.source = { :git => 'https://github.com/paysera/SwiftyUserDefaults.git', :tag => s.version }

  s.requires_arc = true
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '6.0'

  if s.respond_to? 'swift_version'
    s.swift_version = "6.0"
  end
  if s.respond_to? 'swift_versions'
    s.swift_versions = ['6.0']
  end
  s.cocoapods_version = '>= 1.4.0'  

  s.source_files = 'Sources/*.swift'
end
