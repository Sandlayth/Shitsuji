# Resolve each local user's *active* Thunderbird profile directory.
#
# The profile directory name is randomly generated, so it cannot be hard-coded
# in a manifest. This fact scans /home/*/.thunderbird/profiles.ini and returns a
# hash of { username => absolute profile dir } for the profile Thunderbird
# actually launches: the [Install*] section's Default=, else the legacy
# [Profile*] flagged Default=1. Users with no Thunderbird profile are omitted,
# so profiles::thunderbird simply no-ops for them.
Facter.add(:thunderbird_profiles) do
  setcode do
    result = {}

    Dir.glob('/home/*/.thunderbird/profiles.ini').each do |ini|
      tb   = File.dirname(ini)
      user = ini.split(File::SEPARATOR)[2] # /home/<user>/.thunderbird/profiles.ini

      install_default = nil # [Install*] Default= : the profile that launches
      legacy_default  = nil # [Profile*] Path= where Default=1
      section         = nil
      path            = nil
      is_default      = false

      File.foreach(ini) do |line|
        line = line.strip
        if (m = line.match(/^\[(.+)\]$/))
          # Leaving a [Profile*] section: remember its path if it was Default=1.
          legacy_default ||= path if is_default && path
          section    = m[1]
          path       = nil
          is_default = false
          next
        end

        key, sep, val = line.partition('=')
        next if sep.empty?
        key = key.strip
        val = val.strip
        next if val.empty?

        case section
        when /\AInstall/
          install_default = val if key == 'Default'
        when /\AProfile/
          path       = val         if key == 'Path'
          is_default = (val == '1') if key == 'Default'
        end
      end
      # Flush the final section (no trailing header to trigger the check above).
      legacy_default ||= path if is_default && path

      chosen = install_default || legacy_default
      next unless chosen

      result[user] = chosen.start_with?(File::SEPARATOR) ? chosen : File.join(tb, chosen)
    end

    result
  end
end
