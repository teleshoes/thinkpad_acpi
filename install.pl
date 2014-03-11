#!/usr/bin/perl
use strict;
use warnings;

sub createMakefile($);
sub install($);
sub version($);
sub selectSrcDir($);

my $mod = "thinkpad_acpi.ko";
my $modprobeConfFile = "/etc/modprobe.d/thinkpad_acpi.conf";
my $modprobeOpts = "options thinkpad_acpi fan_control=1\n";

sub main(@){
  my $kernel = `uname -r`;
  chomp $kernel;

  my $srcDir = selectSrcDir $kernel;
  die "missing src dir\n" if not defined $srcDir or not -d $srcDir;

  print "installing version in $srcDir/\n";
  chdir $srcDir;
  $ENV{PWD} = "$ENV{PWD}/$srcDir";

  my $buildDir = "/lib/modules/$kernel/build";
  my $modDir = "/lib/modules/$kernel/kernel/drivers/platform/x86/";

  createMakefile $buildDir;

  system "patch thinkpad_acpi.c led.patch";
  system "make";
  system "patch -R thinkpad_acpi.c led.patch";

  install $modDir if -e $mod;

  print "Cleaning..\n";
  system "make clean";
  system "rm Makefile";
}

sub createMakefile($){
  my $buildDir = shift;
  my $cwd = $ENV{PWD};

  my $makefileContent = ''
    .  "obj-m += thinkpad_acpi.o\n"
    .  "\n"
    .  "all:\n"
    .  "\tmake -C $buildDir M=$cwd modules\n"
    .  "\n"
    .  "clean:\n"
    .  "\tmake -C $buildDir M=$cwd clean\n"
    ;

  open FH, "> Makefile";
  print FH $makefileContent;
  close FH;
}

sub install($){
  my $dir = shift;
  print "\n\nsuccess!\n";
  my $now = `date +%s`;
  chomp $now;
  my $bak = "$mod.orig.$now";
  print "copying $mod to $dir\nbackup in $bak\n";
  system "sudo mv $dir/$mod $dir/$bak";
  system "sudo cp $mod $dir";

  print "\n\n";
  print "replacing $modprobeConfFile:\n";
  system "cat", $modprobeConfFile;
  print "with:\n";
  open FH, "| sudo tee $modprobeConfFile";
  print FH $modprobeOpts;
  close FH;
  print "\n\n";

  print "remove and add module thinkpad_acpi\n";
  system "sudo modprobe -r thinkpad_acpi";
  system "sudo modprobe thinkpad_acpi";
}

sub version($){
  my $s = shift;
  my $minorOffset = 100000;
  my ($maj, $min) = ($1, $2) if $s =~ /^(\d+)\.(\d+)/;
  return $maj * $minorOffset + $min;
}

sub selectSrcDir($){
  my $kernel = shift;
  my $kv = version $kernel;

  my @dirs = `ls`;
  chomp foreach @dirs;
  my %vs = map {version($_) => $_} grep {-d $_ and /^\d+\.\d+$/} @dirs;

  my $prev;
  for my $v(sort keys %vs){
    my $dir = $vs{$v};
    if($v > $kv){
      return defined $prev ? $prev : $dir;
    }
    $prev = $dir;
  }
  return $prev;
}

&main(@ARGV);
