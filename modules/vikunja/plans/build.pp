# @summary Build Vikunja from a release tag on the machine running Bolt
#
# For hosts the official builds cannot run on. Those binaries are UPX-packed,
# and the UPX 5 stub needs memfd_create/O_TMPFILE (kernel >= 3.11), and the
# arm-7 one assumes NEON. This build skips UPX, links statically against musl
# with `zig cc`, and targets a CPU profile per arch (arm-7: ARMv7 + VFPv3,
# no NEON, e.g. the Marvell PJ4B in a DS214+).
#
# Needs git, go, node and zig on the controller. The result is cached, so a
# rebuild only happens for a new version.
#
# @param version Vikunja release tag
# @param arch Target arch, as named by the official release files
# @param cache Where sources and binaries are kept
# @param zig zig binary used as the C cross-compiler (cgo, for SQLite)
#
# @example
#   bolt plan run vikunja::build version=v2.7.1 arch=arm-7
plan vikunja::build (
  String               $version,
  Enum['arm-7', 'arm64', 'amd64'] $arch,
  String               $cache = "${system::env('HOME')}/.cache/shitsuji/vikunja",
  String               $zig   = 'zig',
) {
  $target = {
    'arm-7' => { 'goarch' => 'arm',   'goarm' => '7', 'cc' => 'arm-linux-musleabihf -mcpu=cortex_a9-neon' },
    'arm64' => { 'goarch' => 'arm64', 'goarm' => '',  'cc' => 'aarch64-linux-musl' },
    'amd64' => { 'goarch' => 'amd64', 'goarm' => '',  'cc' => 'x86_64-linux-musl' },
  }[$arch]
  $src = "${cache}/src-${version}"
  $out = "${cache}/vikunja-${version}-linux-${arch}"

  if run_command("test -x ${out}", 'localhost', '_catch_errors' => true).ok {
    return $out
  }

  out::message("Building Vikunja ${version} for ${arch} (frontend + backend, takes a few minutes)")
  run_command(@("CMD"/L$), 'localhost')
    set -e; mkdir -p ${cache}; \
    [ -d ${src} ] || git clone -q --depth 1 --branch ${version} https://github.com/go-vikunja/vikunja ${src}; \
    cd ${src}/frontend; \
    pm=\$(sed -n 's/.*"packageManager": "\\([^"]*\\)".*/\\1/p' package.json); \
    [ -f dist/index.html ] || { npx -y \$pm install --frozen-lockfile && npx -y \$pm run build; }
    | CMD
  $env = {
    'CGO_ENABLED' => '1', 'GOOS' => 'linux', 'GOARCH' => $target['goarch'], 'GOARM' => $target['goarm'],
    'CC' => "${zig} cc -target ${target['cc']}",
  }
  run_command(@("CMD"/L$), 'localhost', '_env_vars' => $env)
    cd ${src} && go build -tags osusergo -o ${out}.new \
      -ldflags '-s -w -X "code.vikunja.io/api/pkg/version.Version=${version}" -linkmode external -extldflags -static' . \
    && mv ${out}.new ${out}
    | CMD
  return $out
}
