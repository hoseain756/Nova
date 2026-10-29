Pod::Spec.new do |s|
  s.name             = 'nova_ios_torrent'
  s.version          = '0.1.0'
  s.summary          = 'Embedded on-device torrent engine for NOVA on iOS.'
  s.description      = 'NOVA bridge to the locally bound TorrServerKit engine.'
  s.homepage         = 'https://github.com/hoseain756/Nova'
  s.license          = { :type => 'GPL-3.0' }
  s.author           = { 'NOVA' => 'NOVA' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.vendored_frameworks = 'Frameworks/TorrServerKit.xcframework'
  s.dependency 'Flutter'
  s.platform = :ios, '18.0'
  s.swift_version = '5.0'
  s.static_framework = true
end
