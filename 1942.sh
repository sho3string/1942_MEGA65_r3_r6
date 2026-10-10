#!/usr/bin/env bash
set -euo pipefail
ZIP='1942.zip'; OUT='arcade/1942'; SORT=1
usage() { echo "Usage: $0 [1942.zip] [-o directory] [--no-sort-objects]"; }
if [[ $# -gt 0 && "$1" != -* ]]; then ZIP=$1; shift; fi
while (($#)); do
 case "$1" in
 -o|--out) [[ $# -ge 2 ]] || { usage; exit 1; }; OUT=$2; shift 2;;
 --sort-objects) SORT=1; shift;;
 --no-sort-objects) SORT=0; shift;;
 -h|--help) usage; exit 0;;
 *) usage >&2; exit 1;;
 esac
done
for cmd in unzip perl; do command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 1; }; done
[[ -f "$ZIP" ]] || { echo "ZIP not found: $ZIP" >&2; exit 1; }
mkdir -p "$OUT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
chip() {
  # Extract the exact ZIP member (last duplicate wins, as Python ZipFile.read does).
  perl -MIO::Uncompress::Unzip -e '
    use strict; use warnings;
    my ($zip,$wanted,$dest)=@ARGV;
    my $z=IO::Uncompress::Unzip->new($zip) or die "Cannot open ZIP: $IO::Uncompress::Unzip::UnzipError\n";
    my $found=0;
    for (;;) {
      my $info=$z->getHeaderInfo();
      if ($info->{Name} eq $wanted) {
        open my $out, ">:raw", $dest or die "$dest: $!\n";
        my $buffer;
        while ((my $n=$z->read($buffer)) > 0) { print {$out} $buffer or die $! }
        close $out or die $!;
        $found=1;
      }
      last unless $z->nextStream();
    }
    die "Missing ROM: $wanted\n" unless $found;
  ' "$ZIP" "$1" "$2"
  [[ -s "$2" ]] || { echo "Empty ROM: $1" >&2; exit 1; }
}
for n in srb-03.m3 srb-04.m4 srb-05.m5 srb-06.m6 srb-07.m7 sr-01.c11 sr-02.f2 sr-16.n1 sr-14.l1 sr-17.n2 sr-15.l2 sr-08.a1 sr-09.a2 sr-10.a3 sr-11.a4 sr-12.a5 sr-13.a6 sb-5.e8 sb-6.e9 sb-7.e10 sb-0.f1 sb-4.d6 sb-8.k3 sb-2.d1 sb-3.d2 sb-1.k6; do chip "$n" "$TMP/$n"; done
cat "$TMP/srb-03.m3" "$TMP/srb-04.m4" "$TMP/srb-05.m5" "$TMP/srb-06.m6" "$TMP/srb-06.m6" "$TMP/srb-07.m7" > "$OUT/1942_main.rom"
cp "$TMP/sr-01.c11" "$OUT/1942_sound.rom"
perl -e 'use strict; use warnings; binmode STDOUT; local $/; open my $f,"<:raw",$ARGV[0] or die $!; my $s=<$f>; die "odd character ROM size\n" if length($s)%2; for(my $i=0;$i<length($s);$i+=2){print substr($s,$i+1,1),substr($s,$i,1)}' "$TMP/sr-02.f2" > "$OUT/1942_char.rom"
perl -e 'use strict; use warnings; binmode STDOUT; my $lanes=shift; my @a; for my $p (@ARGV){open my $f,"<:raw",$p or die $!; local $/; push @a,scalar(<$f>)} die "invalid lane count\n" if @a%$lanes; for(my $g=0;$g<@a;$g+=$lanes){my $len=length($a[$g]); for my $k(1..$lanes-1){die "lane length mismatch\n" if length($a[$g+$k])!=$len} for(my $i=0;$i<$len;$i++){for(my $k=0;$k<$lanes;$k++){print substr($a[$g+$k],$i,1)}}}' 2 "$TMP/sr-16.n1" "$TMP/sr-14.l1" "$TMP/sr-17.n2" "$TMP/sr-15.l2" > "$OUT/1942_obj.rom"
perl -e 'use strict; use warnings; binmode STDOUT; my $lanes=shift; my @a; for my $p (@ARGV){open my $f,"<:raw",$p or die $!; local $/; push @a,scalar(<$f>)} die "invalid lane count\n" if @a%$lanes; for(my $g=0;$g<@a;$g+=$lanes){my $len=length($a[$g]); for my $k(1..$lanes-1){die "lane length mismatch\n" if length($a[$g+$k])!=$len} for(my $i=0;$i<$len;$i++){for(my $k=0;$k<$lanes;$k++){print substr($a[$g+$k],$i,1)}}}' 4 "$TMP/sr-08.a1" "$TMP/sr-10.a3" "$TMP/sr-12.a5" "$TMP/sr-12.a5" "$TMP/sr-09.a2" "$TMP/sr-11.a4" "$TMP/sr-13.a6" "$TMP/sr-13.a6" > "$OUT/1942_scr.rom"
cat "$TMP/sb-5.e8" "$TMP/sb-6.e9" "$TMP/sb-7.e10" "$TMP/sb-0.f1" "$TMP/sb-4.d6" "$TMP/sb-8.k3" "$TMP/sb-2.d1" "$TMP/sb-3.d2" > "$OUT/1942_prom.rom"
perl -e 'binmode STDOUT; print "\0" x 256' >> "$OUT/1942_prom.rom"
cat "$TMP/sb-1.k6" >> "$OUT/1942_prom.rom"
if ((SORT)); then
 perl -e 'use strict; use warnings; binmode STDOUT; open my $f,"<:raw",$ARGV[0] or die $!; local $/; my $s=<$f>; my $out="\0" x length($s); for(my $i=0;$i<length($s);$i++){my $d=($i & ~0x7c)|(($i & 0x40)>>4)|(($i & 0x3c)<<1); substr($out,$d,1)=substr($s,$i,1)} print $out' "$OUT/1942_obj.rom" > "$TMP/sorted"; mv "$TMP/sorted" "$OUT/1942_obj.rom"
fi
perl -e 'use strict; use warnings; use Compress::Raw::Zlib qw(crc32); my @spec=(["1942_main.rom",0x14000],["1942_sound.rom",0x4000],["1942_char.rom",0x2000],["1942_obj.rom",0x10000],["1942_scr.rom",0x10000],["1942_prom.rom",0xa00]); for my $s (@spec){open my $f,"<:raw","$ARGV[0]/$s->[0]" or die $!; local $/; my $d=<$f>; die "Incorrect size for $s->[0]: ".length($d)." expected $s->[1]\n" if length($d)!=$s->[1]; printf "%-20s %7d bytes  CRC32 %08X\n",$s->[0],length($d),crc32($d)}' "$OUT"
echo "Object sorting: $([[ $SORT == 1 ]] && echo hvvvvxx || echo none)"
