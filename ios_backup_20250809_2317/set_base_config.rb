require 'xcodeproj'

proj = Xcodeproj::Project.open('ios/Runner.xcodeproj')
flutter_group = proj.main_group.find_subpath('Flutter', true)

def ensure_file_ref(group, path)
  ref = group.files.find { |f| f.path == path }
  ref ||= group.new_file(path)
  ref
end

debug_ref   = ensure_file_ref(flutter_group, 'Flutter/Debug.xcconfig')
release_ref = ensure_file_ref(flutter_group, 'Flutter/Release.xcconfig')
profile_ref = ensure_file_ref(flutter_group, 'Flutter/Profile.xcconfig')

target = proj.targets.find { |t| t.name == 'Runner' } or abort 'Runner target not found'
target.build_configurations.each do |cfg|
  case cfg.name
  when 'Debug'   then cfg.base_configuration_reference = debug_ref
  when 'Release' then cfg.base_configuration_reference = release_ref
  when 'Profile' then cfg.base_configuration_reference = profile_ref
  end
end

proj.save
puts "✅ Base Configuration set → Flutter/*.xcconfig"
